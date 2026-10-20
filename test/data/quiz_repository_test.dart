import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/learning/active_time.dart';
import 'package:kampuslink/data/learning/progress_repository.dart';
import 'package:kampuslink/data/learning/quiz_repository.dart';
import 'package:kampuslink/data/sync/outbox_repository.dart';

import 'feed_repository_test.dart' show studyBundle;

void main() {
  late AppDatabase db;
  late QuizRepository quiz;
  final t0 = DateTime(2026, 10, 20, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxRepository(db, now: () => t0);
    final progress = ProgressRepository(db, outbox, now: () => t0);
    quiz = QuizRepository(db, outbox, progress, now: () => t0);
    await BundleImporter(db).importBundle(studyBundle());
  });

  tearDown(() => db.close());

  test('answers are saved at once, so the quiz resumes', () async {
    final qs = await quiz.questions(21, 'en');
    expect(qs.length, 3);
    expect(qs.first.prompt, 'Question 1');
    expect(qs.first.options, ['a', 'b', 'c']);
    expect(await quiz.answer(21, qs[0], 1), isTrue);
    expect(await quiz.answer(21, qs[1], 0), isFalse);
    final saved = await quiz.savedAnswers(21);
    expect(saved, {3001: 1, 3002: 0});
    final resumeAt = qs.indexWhere((q) => !saved.containsKey(q.id));
    expect(resumeAt, 2);
    final ops = await db.select(db.outbox).get();
    expect(ops.where((o) => o.kind == 'answer').length, 2);
  });

  test('a wrong answer brings the lesson cards back into the feed', () async {
    final qs = await quiz.questions(21, 'fr');
    await quiz.answer(21, qs[0], 2);
    final rows = await db.select(db.cardProgress).get();
    expect(rows.length, 3);
    for (final r in rows) {
      expect(r.box, 1);
      expect(r.dueAt, t0);
    }
  });

  test('finishing marks the lesson done with its score', () async {
    final qs = await quiz.questions(21, 'fr');
    await quiz.answer(21, qs[0], 1);
    await quiz.finish(21, 33);
    final done = await (db.select(
      db.lessonProgress,
    )..where((t) => t.lessonId.equals(21))).getSingle();
    expect(done.completed, isTrue);
    expect(done.score, 33);
    expect(await quiz.savedAnswers(21), isEmpty);
    final ops = await db.select(db.outbox).get();
    expect(ops.where((o) => o.kind == 'lesson_done').length, 1);
  });

  test('study timer counts only active time and flushes every 30 s', () {
    final flushed = <int>[];
    final counter = ActiveTimeCounter(onFlush: flushed.add);
    final start = DateTime(2026, 10, 20, 9);
    counter.touch(start);
    for (var s = 0; s <= 100; s++) {
      counter.tick(start.add(Duration(seconds: s)));
    }
    // Only the 60 s after the last touch count.
    expect(flushed, [30, 30]);
    expect(counter.pending, 0);
    counter.setForeground(false);
    counter.touch(start.add(const Duration(seconds: 200)));
    for (var s = 200; s <= 230; s++) {
      counter.tick(start.add(Duration(seconds: s)));
    }
    expect(counter.pending, 0);
  });
}
