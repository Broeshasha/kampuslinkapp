import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
double _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// The student's own progress rows on the server (row security: own rows).
class ServerProgress {
  const ServerProgress({
    this.cards = const [],
    this.lessons = const [],
    this.positions = const [],
    this.likes = const {},
    this.saves = const {},
  });

  /// learn_card_progress: card_id, box, due_at, last_reviewed_at
  final List<Map<String, dynamic>> cards;

  /// learn_lesson_progress: lesson_id, score (a row = lesson done)
  final List<Map<String, dynamic>> lessons;

  /// learn_reading_position: lesson_id, block_id, progress, updated_at
  final List<Map<String, dynamic>> positions;

  /// learn_card_likes / learn_card_saves: card ids
  final Set<int> likes;
  final Set<int> saves;
}

class MergeReport {
  const MergeReport({
    this.cards = 0,
    this.lessons = 0,
    this.positions = 0,
    this.flags = 0,
    this.keptLocal = 0,
  });

  final int cards, lessons, positions, flags, keptLocal;

  @override
  String toString() =>
      'merge: cards $cards, lessons $lessons, positions $positions, '
      'likes/saves $flags, kept local (unsent ops) $keptLocal';
}

class _Pending {
  final cards = <int>{};
  final positions = <int>{};
  final likes = <int>{};
  final saves = <int>{};
}

/// MASTER_PLAN 7.6: after a successful sync, bring the server's own rows
/// into the phone (reinstall, second device):
/// card progress = newest last_reviewed_at wins; lesson progress = union
/// (done stays done, best score); reading position = newest updated_at;
/// likes / saves = server value. A row with an UNSENT outbox op for the
/// same key is never overwritten.
class ServerMerge {
  ServerMerge(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<_Pending> _pending() async {
    final p = _Pending();
    final answeredQuestions = <int>{};
    for (final op in await _db.select(_db.outbox).get()) {
      Map<String, dynamic> payload;
      try {
        final v = jsonDecode(op.payloadJson);
        payload = v is Map ? v.cast<String, dynamic>() : const {};
      } on FormatException {
        continue;
      }
      switch (op.kind) {
        case 'review':
          p.cards.add(_int(payload['card_id']));
        case 'reading_position':
          p.positions.add(_int(payload['lesson_id']));
        case 'like':
          p.likes.add(_int(payload['card_id']));
        case 'save':
          p.saves.add(_int(payload['card_id']));
        case 'answer':
          answeredQuestions.add(_int(payload['question_id']));
      }
    }
    if (answeredQuestions.isNotEmpty) {
      // An unsent wrong answer has reset its lesson's cards locally.
      final questions = await (_db.select(
        _db.questions,
      )..where((t) => t.id.isIn(answeredQuestions))).get();
      final lessons = questions.map((q) => q.lessonId).toSet();
      final cards = await (_db.select(
        _db.cards,
      )..where((t) => t.lessonId.isIn(lessons))).get();
      p.cards.addAll(cards.map((c) => c.id));
    }
    return p;
  }

  Future<MergeReport> merge(ServerProgress server) => _db.transaction(() async {
    final pending = await _pending();
    var cards = 0, lessons = 0, positions = 0, flags = 0, kept = 0;

    for (final r in server.cards) {
      final id = _int(r['card_id']);
      if (id == 0) continue;
      if (pending.cards.contains(id)) {
        kept++;
        continue;
      }
      final serverAt = _date(r['last_reviewed_at']);
      final local = await (_db.select(
        _db.cardProgress,
      )..where((t) => t.cardId.equals(id))).getSingleOrNull();
      final localAt = local?.lastReviewedAt;
      if (local != null) {
        if (serverAt == null) continue;
        if (localAt != null && !serverAt.isAfter(localAt)) continue;
      }
      await _db
          .into(_db.cardProgress)
          .insertOnConflictUpdate(
            CardProgressCompanion(
              cardId: Value(id),
              box: Value(_int(r['box']).clamp(1, 5)),
              dueAt: Value(_date(r['due_at'])),
              lastReviewedAt: Value(serverAt),
            ),
          );
      cards++;
    }

    for (final r in server.lessons) {
      final id = _int(r['lesson_id']);
      if (id == 0) continue;
      final local = await (_db.select(
        _db.lessonProgress,
      )..where((t) => t.lessonId.equals(id))).getSingleOrNull();
      final serverScore = _intOrNull(r['score']);
      final localScore = local?.score;
      final best = serverScore == null
          ? localScore
          : (localScore == null || serverScore > localScore
                ? serverScore
                : localScore);
      if (local != null && local.completed && best == localScore) continue;
      await _db
          .into(_db.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion(
              lessonId: Value(id),
              completed: const Value(true),
              score: Value(best),
              completedAt: Value(local?.completedAt ?? _now()),
            ),
          );
      lessons++;
    }

    for (final r in server.positions) {
      final id = _int(r['lesson_id']);
      final blockId = r['block_id']?.toString();
      final serverAt = _date(r['updated_at']);
      if (id == 0 || blockId == null || blockId.isEmpty || serverAt == null) {
        continue;
      }
      if (pending.positions.contains(id)) {
        kept++;
        continue;
      }
      final local = await (_db.select(
        _db.readingPositions,
      )..where((t) => t.lessonId.equals(id))).getSingleOrNull();
      if (local != null && !serverAt.isAfter(local.updatedAt)) continue;
      await _db
          .into(_db.readingPositions)
          .insertOnConflictUpdate(
            ReadingPositionsCompanion(
              lessonId: Value(id),
              blockId: Value(blockId),
              progress: Value(_double(r['progress']).clamp(0.0, 1.0)),
              updatedAt: Value(serverAt),
            ),
          );
      positions++;
    }

    final localRows = await _db.select(_db.cardProgress).get();
    final localLiked = {
      for (final r in localRows)
        if (r.liked) r.cardId,
    };
    final localSaved = {
      for (final r in localRows)
        if (r.saved) r.cardId,
    };
    for (final id in {...server.likes, ...localLiked}) {
      final on = server.likes.contains(id);
      if (on == localLiked.contains(id)) continue;
      if (pending.likes.contains(id)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.cardProgress)
          .insertOnConflictUpdate(
            CardProgressCompanion(cardId: Value(id), liked: Value(on)),
          );
      flags++;
    }
    for (final id in {...server.saves, ...localSaved}) {
      final on = server.saves.contains(id);
      if (on == localSaved.contains(id)) continue;
      if (pending.saves.contains(id)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.cardProgress)
          .insertOnConflictUpdate(
            CardProgressCompanion(cardId: Value(id), saved: Value(on)),
          );
      flags++;
    }

    return MergeReport(
      cards: cards,
      lessons: lessons,
      positions: positions,
      flags: flags,
      keptLocal: kept,
    );
  });
}
