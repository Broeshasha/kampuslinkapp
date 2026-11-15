import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_repository.dart' show dayKey;
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/motivation/motivation_store.dart';
import 'package:kampuslink/data/motivation/prayer_times.dart';
import 'package:kampuslink/data/sync/module_downloader.dart';
import 'package:kampuslink/data/sync/module_sync.dart';

import 'module_sync_test.dart' show FakeServer, serverModule;

void main() {
  test('prayer times in Algiers look right', () {
    final p = prayerTimes(DateTime(2026, 11, 15));
    // Maghrib ~17:3x, Isha ~19:0x in mid November.
    expect(p.maghrib.hour, 17);
    expect(p.isha.isAfter(p.maghrib), isTrue);
    expect(p.isha.difference(p.maghrib).inMinutes, inInclusiveRange(70, 110));
    final june = prayerTimes(DateTime(2027, 6, 13));
    expect(june.maghrib.hour, 20);
  });

  test('anchors stay before quiet hours', () {
    for (final a in StudyAnchor.values) {
      final t = anchorTime(a, DateTime(2027, 6, 21));
      if (t == null) continue;
      expect(t.compareTo('21:30') <= 0, isTrue, reason: '$a $t');
    }
  });

  test('weeks in a row and week start', () {
    final now = DateTime(2026, 11, 18); // Wednesday
    expect(weekStartOf(now), DateTime(2026, 11, 16));
    Set<String> week(DateTime monday, int n) => {
      for (var i = 0; i < n; i++) dayKey(monday.add(Duration(days: i))),
    };
    final days = {
      ...week(DateTime(2026, 11, 9), 5),
      ...week(DateTime(2026, 11, 2), 6),
      ...week(DateTime(2026, 10, 26), 3),
    };
    expect(weeksInRow(days, now, 5), 2);
    expect(weeksInRow(days, now, 6), 0);
    expect(weeksInRow({}, now, 5), 0);
  });

  group('store', () {
    late AppDatabase db;
    var now = DateTime(2026, 11, 16, 18);

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      final server = FakeServer()..lessons[1] = {101: 'a', 102: 'b'};
      await ModuleSyncService(
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
        fetchModules: () async => [serverModule(1, 1)],
      ).sync(['fr']);
    });
    tearDown(() => db.close());

    MotivationStore store() => MotivationStore(db, now: () => now);

    test('no modules -> nothing to do, nothing recorded', () async {
      final m = await store().today([]);
      expect(m.cardsTarget, 0);
      expect(m.lesson, isNull);
      expect(await store().missionDoneOn(now), isFalse);
    });

    test('lesson read today ticks the lesson step; full mission marks the day', () async {
      final s = store();
      var m = await s.today([1]);
      expect(m.lesson?.id, 101);
      expect(m.lessonOk, isFalse);
      await db.into(db.lessonProgress).insertOnConflictUpdate(
        LessonProgressCompanion(
          lessonId: const Value(101),
          completed: const Value(true),
          completedAt: Value(now),
        ),
      );
      m = await s.today([1]);
      expect(m.lessonOk, isTrue);
      expect(m.lesson?.id, 102);
      for (var i = 0; i < 3; i++) {
        await s.countAnswer();
      }
      m = await s.today([1]);
      expect(m.answers, 3);
      expect(m.done, m.cardsOk, reason: 'only the cards can still be open');
      if (m.done) {
        expect(m.weekDays, 1);
        expect(await s.missionDoneOn(now), isTrue);
      }
    });

    test('card target is fixed for the day', () async {
      final a = await store().today([1]);
      final b = await store().today([1]);
      expect(a.cardsTarget, b.cardsTarget);
      expect(a.cardsTarget, lessThanOrEqualTo(15));
    });

    test('my why stays capped and clean', () async {
      await store().setWhy(MyWhy(values: const ['family', 'bogus', 'faith', 'future_job'], text: 'x' * 300));
      final w = await store().why();
      expect(w.values, ['family', 'faith']);
      expect(w.text.length, 200);
      now = DateTime(2026, 11, 16, 18);
    });
  });
}
