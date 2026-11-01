import 'dart:math' show Random;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/cases/case_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_pool.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';
import 'package:kampuslink/data/learning/feed_repository.dart';
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/sync/download_stats.dart';
import 'package:kampuslink/data/sync/module_downloader.dart';
import 'package:kampuslink/data/sync/module_sync.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

Map<String, dynamic> _lesson(int id, List<String> langs) => {
  'id': id,
  'position': id % 100,
  'unit': {'ref': 'u${(id % 100 + 1) ~/ 2}', 'number': (id % 100 + 1) ~/ 2},
  'i18n': {
    for (final l in langs) l: {'title': 'L$id $l'},
  },
  'cards': [
    for (var c = 1; c <= 3; c++)
      {
        'id': id * 10 + c,
        'position': c,
        'i18n': {
          for (final l in langs) l: {'front': 'f$c $l', 'back': 'b $l'},
        },
      },
  ],
  'questions': const [],
};

void main() {
  late AppDatabase db;
  final calls = <int>[];
  var stop = false;
  var bytes = 0;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    calls.clear();
    stop = false;
    bytes = 0;
  });
  tearDown(() => db.close());

  ModuleSyncService service() => ModuleSyncService(
    modules: ModuleRepository(db),
    fetchModules: () async => [
      {
        'module_id': 1,
        'name': 'Ondes',
        'semester': 3,
        'version': 1,
        'lessons': 4,
      },
    ],
    shouldStop: () => stop,
    downloader: ModuleDownloader(
      db,
      BundleImporter(db),
      fetchManifest: (m, langs) async => {
        'version': 1,
        'extras_rev': 'x1',
        'lessons': [
          for (var i = 1; i <= 4; i++)
            {'id': 100 + i, 'position': i, 'rev': 'a'},
        ],
      },
      fetchLesson: (id, langs) async {
        calls.add(id);
        if (calls.length == 2) stop = true; // "Pause" while lesson 2 arrives
        return _lesson(id, langs);
      },
      fetchExtras: (m, langs) async => {
        'glossary': const [],
        'resources': const [],
        'sets': const [],
      },
      fetchBundle: (m, langs) async => const {},
      concurrency: 1,
      sleep: (_) async {},
      shouldStop: () => stop,
      onBytes: (n) => bytes += n,
    ),
  );

  test('Pause stops between lessons; Download now resumes the rest', () async {
    await service().sync(['fr']);
    expect(calls, [101, 102]);
    expect(bytes, greaterThan(0));
    var m = await (db.select(
      db.modules,
    )..where((t) => t.id.equals(1))).getSingle();
    expect(m.localVersion, 0, reason: 'not complete while paused');

    stop = false;
    await service().sync(['fr']);
    expect(calls, [101, 102, 103, 104], reason: 'only the missing lessons');
    m = await (db.select(db.modules)..where((t) => t.id.equals(1))).getSingle();
    expect(m.localVersion, 1);

    final sizes = await storedBytesPerModule(db);
    expect(sizes[1], greaterThan(0));
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(3 * 1024 * 1024 + 1), '3.0 MB');
  });

  test('offline cold start: the feed is built from the phone only', () async {
    // Downloaded once, then no network at all: no fetch function is called.
    await service().sync(['fr']); // paused after lesson 2 (shared fake)
    stop = false;
    await service().sync(['fr']); // the rest
    final now = DateTime(2026, 11, 2, 12);
    final outbox = OutboxRepository(db, now: () => now);
    final loader = FeedPoolLoader(
      db,
      FeedRepository(db, outbox, now: () => now),
      CaseRepository(db, outbox),
    );
    final pool = await loader.load(now: now);
    final fresh = pool[FeedBucket.fresh]!;
    expect(fresh, isNotEmpty);
    // Lessons 101-102 = chapter 1, 103-104 = chapter 2: a new student sees
    // chapter 1 first, then chapter 2, nothing beyond.
    expect(fresh.first.lessonId, anyOf(101, 102));
    expect(fresh.map((i) => i.lessonId).toSet(), {101, 102, 103, 104});
    final queue = buildFeedQueue(
      pool: pool,
      random: Random(1),
      now: now,
      repeat: false,
    );
    expect(queue.map((i) => i.key).toSet().length, queue.length);
  });
}
