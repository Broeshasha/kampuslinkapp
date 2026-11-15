import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/assess/assess_store.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/sync/module_downloader.dart';
import 'package:kampuslink/data/sync/module_sync.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

import 'module_sync_test.dart' show FakeServer, serverModule;

void main() {
  late AppDatabase db;
  late FakeServer server;
  late List<Map<String, dynamic>> moduleList;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer()..lessons[1] = {101: 'a', 102: 'b'};
    moduleList = [serverModule(1, 1)];
  });
  tearDown(() => db.close());

  ModuleSyncService service() => ModuleSyncService(
    modules: ModuleRepository(db),
    downloader: ModuleDownloader(
      db,
      BundleImporter(db),
      fetchManifest: server.manifest,
      fetchLesson: server.lesson,
      fetchExtras: server.extras,
      fetchBundle: server.bundle,
      sleep: (_) async {},
    ),
    fetchModules: () async => moduleList,
  );

  Future<int> lessonCount() async => (await db.select(db.lessons).get()).length;

  test('a module removed and given back downloads its lessons again', () async {
    await service().sync(['fr']);
    expect(await lessonCount(), 2);
    moduleList = [serverModule(2, 1)];
    await service().sync(['fr']);
    expect(await lessonCount(), 0);
    final marks = await (db.select(
      db.keyValues,
    )..where((t) => t.name.like('lesson_rev:%'))).get();
    expect(marks, isEmpty, reason: 'download marks deleted with the module');
    moduleList = [serverModule(1, 1)];
    await service().sync(['fr']);
    expect(await lessonCount(), 2);
  });

  test('a stray rev mark without the lesson row heals itself', () async {
    await service().sync(['fr']);
    await (db.delete(db.lessons)..where((t) => t.id.equals(101))).go();
    await (db.update(db.modules)..where((t) => t.id.equals(1))).write(
      const ModulesCompanion(localVersion: Value(0)),
    );
    await service().sync(['fr']);
    expect(await lessonCount(), 2);
  });

  test('an empty module list never deletes downloads', () async {
    await service().sync(['fr']);
    moduleList = [];
    await service().sync(['fr']);
    expect(await lessonCount(), 2);
    expect(await db.select(db.modules).get(), hasLength(1));
  });

  test('a weaker second try keeps the best quiz score', () async {
    final repo = ProgressRepository(db, OutboxRepository(db));
    await repo.completeLesson(5, score: 80);
    await repo.completeLesson(5, score: 40);
    await repo.completeLesson(5);
    final row = await (db.select(
      db.lessonProgress,
    )..where((t) => t.lessonId.equals(5))).getSingle();
    expect(row.score, 80);
    await repo.completeLesson(5, score: 90);
    final again = await (db.select(
      db.lessonProgress,
    )..where((t) => t.lessonId.equals(5))).getSingle();
    expect(again.score, 90);
  });

  test('a practice chapter that fails is not "complete"', () async {
    final store = AssessStore(db, OutboxRepository(db));
    final manifest = {
      'practice': [
        {'chapter_ref': 'ch1', 'rev': 'r1'},
        {'chapter_ref': 'ch2', 'rev': 'r2'},
      ],
      'exams': const [],
    };
    final partial = await store.applyManifest(
      1,
      manifest,
      fetchPractice: (ref) async =>
          ref == 'ch2' ? throw Exception('offline') : const <Object?>[],
      fetchPaper: (id) async => const <String, dynamic>{},
    );
    expect(partial, isFalse);
    final full = await store.applyManifest(
      1,
      manifest,
      fetchPractice: (ref) async => const <Object?>[],
      fetchPaper: (id) async => const <String, dynamic>{},
    );
    expect(full, isTrue);
  });
}
