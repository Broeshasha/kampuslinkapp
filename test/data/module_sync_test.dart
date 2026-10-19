import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/sync/module_sync.dart';

Map<String, dynamic> serverModule(int id, int version, {int semester = 3}) => {
  'module_id': id,
  'name': 'Module $id',
  'semester': semester,
  'ue_category': 'UEF',
  'academic_year': 'L2',
  'version': version,
  'lessons': version == 0 ? 0 : 1,
  'lessons_done': 0,
  'resources': 0,
};

Map<String, dynamic> bundleFor(int id, int version) => {
  'schema_version': 2,
  'module': {'id': id, 'name': 'Module $id', 'semester': 3},
  'version': version,
  'languages': ['fr'],
  'lessons': [
    {
      'id': id * 100,
      'position': 1,
      'i18n': {
        'fr': {'title': 't'},
      },
      'cards': const [],
      'questions': const [],
    },
  ],
  'resources': const [],
  'glossary': const [],
};

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ModuleSyncService service({
    required FetchModules fetchModules,
    required FetchBundle fetchBundle,
  }) => ModuleSyncService(
    modules: ModuleRepository(db),
    importer: BundleImporter(db),
    fetchModules: fetchModules,
    fetchBundle: fetchBundle,
  );

  test('downloads only modules with new content, nothing twice', () async {
    var calls = 0;
    final s = service(
      fetchModules: () async => [serverModule(1, 1), serverModule(2, 0)],
      fetchBundle: (id, langs) async {
        calls++;
        return bundleFor(id, 1);
      },
    );
    final first = await s.sync(['fr']);
    expect(first.downloaded, 1);
    expect(await db.select(db.modules).get(), hasLength(2));
    expect(await db.select(db.lessons).get(), hasLength(1));
    final second = await s.sync(['fr']);
    expect(second.downloaded, 0);
    expect(calls, 1);
  });

  test('modules that are no longer yours disappear, downloads kept', () async {
    var list = [serverModule(1, 1), serverModule(2, 1)];
    final s = service(
      fetchModules: () async => list,
      fetchBundle: (id, langs) async => bundleFor(id, 1),
    );
    await s.sync(['fr']);
    list = [serverModule(1, 1)];
    await s.sync(['fr']);
    final modules = await db.select(db.modules).get();
    expect(modules.single.id, 1);
    expect(modules.single.localVersion, 1);
    expect(await db.select(db.lessons).get(), hasLength(1));
  });

  test('one failing module does not stop the others', () async {
    final s = service(
      fetchModules: () async => [serverModule(1, 1), serverModule(2, 1)],
      fetchBundle: (id, langs) async {
        if (id == 2) throw TimeoutException('slow');
        return bundleFor(id, 1);
      },
    );
    final r = await s.sync(['fr']);
    expect(r.downloaded, 1);
    expect(r.failed, [2]);
    expect(r.failure, isA<OfflineFailure>());
  });

  test('a dead network keeps everything already on the phone', () async {
    var online = true;
    final s = service(
      fetchModules: () async {
        if (!online) throw TimeoutException('offline');
        return [serverModule(1, 1)];
      },
      fetchBundle: (id, langs) async => bundleFor(id, 1),
    );
    await s.sync(['fr']);
    online = false;
    final r = await s.sync(['fr']);
    expect(r.failure, isA<OfflineFailure>());
    expect(await db.select(db.modules).get(), hasLength(1));
    expect(await db.select(db.lessons).get(), hasLength(1));
  });
}
