import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/sync/download_failure.dart';
import 'package:kampuslink/data/sync/module_downloader.dart';
import 'package:kampuslink/data/sync/module_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> serverModule(int id, int version) => {
  'module_id': id,
  'name': 'Module $id',
  'semester': 3,
  'ue_category': 'UEF',
  'academic_year': 'L2',
  'version': version,
  'lessons': version == 0 ? 0 : 3,
  'lessons_done': 0,
  'resources': 0,
};

/// A fake server: lessons id -> rev, per module.
class FakeServer {
  final lessons = <int, Map<int, String>>{};
  final failLesson = <int>{};
  bool missingFunctions = false;
  final lessonCalls = <int, int>{};
  final asked = <int, List<String>>{};
  var extrasCalls = 0;
  var bundleCalls = 0;
  int version = 1;

  String missingCode = 'PGRST202';

  Never _missing() => throw PostgrestException(
    message: 'Could not find the function public.get_module_manifest',
    code: missingCode,
  );

  Map<String, dynamic> lessonJson(int id, List<String> langs) => {
    'id': id,
    'position': id % 100,
    'i18n': {
      for (final l in langs) l: {'title': 'L$id $l'},
    },
    'cards': [
      {
        'id': id * 10,
        'position': 1,
        'i18n': {
          for (final l in langs) l: {'front': 'f $l', 'back': 'b $l'},
        },
      },
    ],
    'questions': const [],
  };

  Future<Map<String, dynamic>> manifest(int m, List<String> langs) async {
    if (missingFunctions) _missing();
    final ls = lessons[m] ?? const <int, String>{};
    return {
      'schema_version': 3,
      'version': version,
      'extras_rev': 'x$version',
      'lessons': [
        for (final e in ls.entries)
          {'id': e.key, 'position': e.key % 100, 'rev': e.value},
      ],
    };
  }

  Future<Map<String, dynamic>> lesson(int id, List<String> langs) async {
    lessonCalls[id] = (lessonCalls[id] ?? 0) + 1;
    asked[id] = langs;
    if (failLesson.contains(id)) throw TimeoutException('slow');
    return lessonJson(id, langs);
  }

  Future<Map<String, dynamic>> extras(int m, List<String> langs) async {
    extrasCalls++;
    return {'glossary': const [], 'resources': const [], 'sets': const []};
  }

  Future<Map<String, dynamic>> bundle(int m, List<String> langs) async {
    bundleCalls++;
    return {
      'schema_version': 3,
      'module': {'id': m, 'name': 'Module $m', 'semester': 3},
      'version': version,
      'languages': langs,
      'lessons': [
        for (final id in (lessons[m] ?? const <int, String>{}).keys)
          lessonJson(id, langs),
      ],
      'resources': const [],
      'glossary': const [],
    };
  }
}

void main() {
  late AppDatabase db;
  late FakeServer server;
  late List<Map<String, dynamic>> moduleList;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    moduleList = [serverModule(1, 1)];
  });
  tearDown(() => db.close());

  ModuleDownloader downloader() => ModuleDownloader(
    db,
    BundleImporter(db),
    fetchManifest: server.manifest,
    fetchLesson: server.lesson,
    fetchExtras: server.extras,
    fetchBundle: server.bundle,
    sleep: (_) async {},
  );

  ModuleSyncService service() => ModuleSyncService(
    modules: ModuleRepository(db),
    downloader: downloader(),
    fetchModules: () async => moduleList,
  );

  Future<List<int>> lessonIds() async =>
      [for (final l in await db.select(db.lessons).get()) l.id]..sort();

  Future<ModuleRow> module(int id) =>
      (db.select(db.modules)..where((t) => t.id.equals(id))).getSingle();

  test('first sync downloads every lesson and the extras', () async {
    server.lessons[1] = {101: 'a', 102: 'a', 103: 'a'};
    final r = await service().sync(['fr']);
    expect(r.downloaded, 1);
    expect(r.failure, isNull);
    expect(await lessonIds(), [101, 102, 103]);
    expect(server.extrasCalls, 1);
    final m = await module(1);
    expect(m.localVersion, 1);
    expect(m.languages, 'fr');
  });

  test(
    'manifest diff: only new and changed lessons, removed ones go',
    () async {
      server.lessons[1] = {101: 'a', 102: 'a', 103: 'a'};
      await service().sync(['fr']);
      server.lessonCalls.clear();
      server.version = 2;
      moduleList = [serverModule(1, 2)];
      server.lessons[1] = {101: 'a', 102: 'b', 104: 'a'};
      final r = await service().sync(['fr']);
      expect(r.failure, isNull);
      expect(server.lessonCalls.keys.toSet(), {102, 104});
      expect(await lessonIds(), [101, 102, 104]);
      expect(
        await (db.select(db.cards)..where((t) => t.lessonId.equals(103))).get(),
        isEmpty,
      );
      expect((await module(1)).localVersion, 2);
    },
  );

  test(
    'one lesson failing 3 times does not stop the others; resume later',
    () async {
      server.lessons[1] = {101: 'a', 102: 'a', 103: 'a'};
      server.failLesson.add(102);
      final r = await service().sync(['fr']);
      expect(r.downloaded, 0);
      expect(r.failure, isA<ServerFailure>());
      final f = r.failures[1]!;
      expect(f.kind, DownloadErrorKind.timeout);
      expect(f.step, contains('lesson 2/3'));
      expect(f.attempts, 4);
      expect(server.lessonCalls[102], 4);
      expect(await lessonIds(), [101, 103]);
      expect((await module(1)).localVersion, 0);

      // The connection comes back: only the missing lesson is fetched.
      server.failLesson.clear();
      server.lessonCalls.clear();
      final again = await service().sync(['fr']);
      expect(again.failure, isNull);
      expect(server.lessonCalls.keys, [102]);
      expect(await lessonIds(), [101, 102, 103]);
      expect((await module(1)).localVersion, 1);
    },
  );

  test('language top-up merges and keeps the other languages', () async {
    server.lessons[1] = {101: 'a'};
    await service().sync(['fr']);
    server.lessonCalls.clear();
    final r = await service().sync(['fr', 'ar']);
    expect(r.failure, isNull);
    expect(server.asked[101], ['ar']);
    final lesson = await db.select(db.lessons).getSingle();
    final i18n = jsonDecode(lesson.i18nJson) as Map;
    expect(i18n.keys.toSet(), {'fr', 'ar'});
    final card = await db.select(db.cards).getSingle();
    expect((jsonDecode(card.i18nJson) as Map).keys.toSet(), {'fr', 'ar'});
    expect((await module(1)).languages, 'ar,fr');
  });

  test('reader top-up of one lesson keeps the stored languages', () async {
    server.lessons[1] = {101: 'a'};
    await service().sync(['fr']);
    final failure = await downloader().topUpLesson(101, 'en');
    expect(failure, isNull);
    final lesson = await db.select(db.lessons).getSingle();
    expect((jsonDecode(lesson.i18nJson) as Map).keys.toSet(), {'fr', 'en'});
  });

  test(
    'falls back to get_module_bundle when the functions are missing',
    () async {
      server.lessons[1] = {101: 'a', 102: 'a'};
      server.missingFunctions = true;
      final r = await service().sync(['fr']);
      expect(r.failure, isNull);
      expect(server.bundleCalls, 1);
      expect(server.lessonCalls, isEmpty);
      expect(await lessonIds(), [101, 102]);
    },
  );

  test('modules without content are not downloaded', () async {
    moduleList = [serverModule(1, 1), serverModule(2, 0)];
    server.lessons[1] = {101: 'a'};
    final r = await service().sync(['fr']);
    expect(r.downloaded, 1);
    expect(await db.select(db.modules).get(), hasLength(2));
  });

  test('a dead network keeps everything already on the phone', () async {
    server.lessons[1] = {101: 'a'};
    var online = true;
    final s = ModuleSyncService(
      modules: ModuleRepository(db),
      downloader: downloader(),
      fetchModules: () async {
        if (!online) throw TimeoutException('offline');
        return moduleList;
      },
    );
    await s.sync(['fr']);
    online = false;
    final r = await s.sync(['fr']);
    expect(r.failure, isA<OfflineFailure>());
    expect(await lessonIds(), [101]);
  });
}
