import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/feed_repository.dart' show dayKey;
import 'package:kampuslink/data/modules/module_repository.dart';
import 'package:kampuslink/data/motivation/bac_readiness.dart';
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
    // a frozen missed week keeps the run going
    final withHole = {...week(DateTime(2026, 11, 2), 5), ...week(DateTime(2026, 10, 26), 5)};
    expect(weeksInRow(withHole, now, 5), 0);
    expect(weeksInRow(withHole, now, 5, frozen: {'2026-11-09'}), 3);
  });

  test('bac countdown: weeks until the date is confirmed', () {
    final now = DateTime.utc(2026, 11, 15, 12);
    const date = '2027-06-13T08:30:00+01:00';
    final weeks = bacCountdown(date, false, now)!;
    expect(weeks.days, isFalse);
    expect(weeks.value, inInclusiveRange(29, 31));
    final days = bacCountdown(date, true, now)!;
    expect(days.days, isTrue);
    expect(days.value, inInclusiveRange(209, 211));
    expect(bacCountdown(date, true, DateTime.utc(2027, 7)), isNull);
    expect(bacCountdown(null, true, now), isNull);
  });

  test('bac subjects: only the ones the student sees', () {
    final config = {
      'se': [
        {'key': 'svt', 'modules': [3001], 'coef': 6},
        {'key': 'phys', 'modules': [3002, 3003], 'coef': 5},
      ],
    };
    final s = BacSubject.listFrom(config, {3002});
    expect(s.map((e) => e.key), ['phys']);
    expect(s.single.coef, 5);
    expect(BacSubject.listFrom('bad', {3001}), isEmpty);
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

    test('readiness grows with finished lessons', () async {
      const sub = BacSubject(key: 'x', modules: [1], coef: 1);
      final before = (await bacReadiness(db, [sub])).single.value;
      await db.into(db.lessonProgress).insertOnConflictUpdate(
        LessonProgressCompanion(
          lessonId: const Value(101),
          completed: const Value(true),
          completedAt: Value(now),
        ),
      );
      final after = (await bacReadiness(db, [sub])).single.value;
      expect(after, greaterThan(before));
      expect(after, lessThanOrEqualTo(1));
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
