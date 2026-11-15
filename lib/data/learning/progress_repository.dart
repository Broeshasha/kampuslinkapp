import 'package:drift/drift.dart';

import '../../core/analytics/analytics.dart';
import '../db/app_database.dart';
import '../sync/outbox_repository.dart';
import 'leitner.dart';

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Local-first progress (MASTER_PLAN 7.6): the phone updates its own tables
/// immediately (works offline) AND queues the op for the server, atomically.
class ProgressRepository {
  ProgressRepository(this._db, this._outbox, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final DateTime Function() _now;

  Future<void> reviewCard(int cardId, {required bool correct}) =>
      _db.transaction(() async {
        final now = _now();
        final current = await (_db.select(
          _db.cardProgress,
        )..where((t) => t.cardId.equals(cardId))).getSingleOrNull();
        final next = leitnerNext(
          box: current?.box ?? 1,
          correct: correct,
          now: now,
        );
        await _db
            .into(_db.cardProgress)
            .insertOnConflictUpdate(
              CardProgressCompanion(
                cardId: Value(cardId),
                box: Value(next.box),
                dueAt: Value(next.dueAt),
                lastReviewedAt: Value(now),
              ),
            );
        await _outbox.enqueue('review', {
          'card_id': cardId,
          'correct': correct,
          // B09: when it happened (offline work keeps its real day).
          'at': _now().toUtc().toIso8601String(),
        });
      });

  Future<void> completeLesson(int lessonId, {int? score}) => _db.transaction(
    () async {
      // B08: a second, weaker try never lowers the best score.
      final old = (await (_db.select(
        _db.lessonProgress,
      )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull())?.score;
      final best = old == null || (score != null && score > old) ? score : old;
      await _db
          .into(_db.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion(
              lessonId: Value(lessonId),
              completed: const Value(true),
              score: Value(best),
              completedAt: Value(_now()),
            ),
          );
      await _outbox.enqueue('lesson_done', {
        'lesson_id': lessonId,
        'score': score,
        'at': _now().toUtc().toIso8601String(),
      });
      Analytics.log('lesson_complete');
    },
  );

  /// Latest position wins; only the newest op per lesson stays queued.
  Future<void> saveReadingPosition(
    int lessonId,
    String blockId,
    double progress,
  ) => _db.transaction(() async {
    final now = _now();
    final p = progress.clamp(0.0, 1.0).toDouble();
    await _db
        .into(_db.readingPositions)
        .insertOnConflictUpdate(
          ReadingPositionsCompanion(
            lessonId: Value(lessonId),
            blockId: Value(blockId),
            progress: Value(p),
            updatedAt: Value(now),
          ),
        );
    await _outbox.enqueue('reading_position', {
      'lesson_id': lessonId,
      'block_id': blockId,
      'progress': p,
      'at': now.toUtc().toIso8601String(),
    }, replaceKey: 'reading_position:$lessonId');
  });

  /// Active study time (max 900 s per call, like the server).
  Future<void> logStudySeconds(int seconds) async {
    if (seconds <= 0) return;
    final capped = seconds > 900 ? 900 : seconds;
    final day = _dayKey(_now());
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.studyDays,
      )..where((t) => t.day.equals(day))).getSingleOrNull();
      await _db
          .into(_db.studyDays)
          .insertOnConflictUpdate(
            StudyDaysCompanion(
              day: Value(day),
              seconds: Value((row?.seconds ?? 0) + capped),
            ),
          );
      // B09: never a replace key (each minute counts); the day travels too.
      await _outbox.enqueue('study_time', {
        'seconds': capped,
        'at': _now().toUtc().toIso8601String(),
      });
    });
  }
}
