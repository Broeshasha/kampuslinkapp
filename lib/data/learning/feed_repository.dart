import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../lessons/lesson_content.dart';
import '../lessons/lesson_repository.dart';
import '../sync/outbox_repository.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A streak day = at least 5 minutes of active study (BACKEND_CONTRACT C).
const streakDaySeconds = 300;

/// Days in a row with a streak day, ending today (or yesterday if today
/// is not reached yet).
int localStreak(Map<String, int> secondsByDay, DateTime today) {
  var day = DateTime(today.year, today.month, today.day);
  if ((secondsByDay[dayKey(day)] ?? 0) < streakDaySeconds) {
    day = day.subtract(const Duration(days: 1));
  }
  var count = 0;
  while ((secondsByDay[dayKey(day)] ?? 0) >= streakDaySeconds) {
    count++;
    day = day.subtract(const Duration(days: 1));
  }
  return count;
}

/// One flashcard of the feed with its module and the student's progress.
class FeedCard {
  const FeedCard({
    required this.card,
    required this.module,
    required this.lessonPosition,
    this.progress,
  });

  final CardRow card;
  final ModuleRow module;
  final int lessonPosition;
  final CardProgressRow? progress;

  bool get liked => progress?.liked ?? false;
  bool get saved => progress?.saved ?? false;

  /// Front / back in [wanted] (else French, else any).
  ({String front, String back, String language}) text(String wanted) {
    Map<String, dynamic> i18n;
    try {
      final v = jsonDecode(card.i18nJson);
      i18n = v is Map ? v.cast<String, dynamic>() : const {};
    } on FormatException {
      i18n = const {};
    }
    final lang = pickLanguage(i18n.keys, wanted);
    final t = i18n[lang];
    final m = t is Map ? t.cast<String, dynamic>() : const <String, dynamic>{};
    return (
      front: '${m['front'] ?? ''}',
      back: '${m['back'] ?? ''}',
      language: lang,
    );
  }
}

/// Home feed (local copy of get_home_cards' order), likes / saves, study
/// days and the Continue source. Works fully offline.
class FeedRepository {
  FeedRepository(this._db, this._outbox, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final DateTime Function() _now;

  Future<List<FeedCard>> _all() async {
    final rows = await _db.select(_db.cards).join([
      innerJoin(_db.modules, _db.modules.id.equalsExp(_db.cards.moduleId)),
      leftOuterJoin(_db.lessons, _db.lessons.id.equalsExp(_db.cards.lessonId)),
      leftOuterJoin(
        _db.cardProgress,
        _db.cardProgress.cardId.equalsExp(_db.cards.id),
      ),
    ]).get();
    return [
      for (final r in rows)
        FeedCard(
          card: r.readTable(_db.cards),
          module: r.readTable(_db.modules),
          lessonPosition: r.readTableOrNull(_db.lessons)?.position ?? 0,
          progress: r.readTableOrNull(_db.cardProgress),
        ),
    ];
  }

  /// Due cards first (oldest due first), then new cards (module, lesson,
  /// card order). [ahead] = only cards not due yet, soonest first.
  Future<List<FeedCard>> feed({bool ahead = false, int limit = 40}) async {
    final now = _now();
    final all = await _all();
    final due = <FeedCard>[];
    final fresh = <FeedCard>[];
    final later = <FeedCard>[];
    for (final c in all) {
      final at = c.progress?.dueAt;
      if (at == null) {
        fresh.add(c);
      } else if (at.isAfter(now)) {
        later.add(c);
      } else {
        due.add(c);
      }
    }
    int byDue(FeedCard a, FeedCard b) =>
        a.progress!.dueAt!.compareTo(b.progress!.dueAt!);
    due.sort(byDue);
    later.sort(byDue);
    fresh.sort((a, b) {
      final m = a.module.id.compareTo(b.module.id);
      if (m != 0) return m;
      final l = a.lessonPosition.compareTo(b.lessonPosition);
      if (l != 0) return l;
      return a.card.position.compareTo(b.card.position);
    });
    final list = ahead ? later : [...due, ...fresh];
    return list.take(limit).toList();
  }

  /// When the next card becomes due (null = nothing scheduled).
  Future<DateTime?> nextDueAt() async {
    final now = _now();
    final row =
        await (_db.select(_db.cardProgress)
              ..where((t) => t.dueAt.isBiggerThanValue(now))
              ..orderBy([(t) => OrderingTerm.asc(t.dueAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.dueAt;
  }

  Future<void> setLiked(int cardId, {required bool on}) =>
      _db.transaction(() async {
        await _db
            .into(_db.cardProgress)
            .insertOnConflictUpdate(
              CardProgressCompanion(cardId: Value(cardId), liked: Value(on)),
            );
        await _outbox.enqueue('like', {
          'card_id': cardId,
          'on': on,
        }, replaceKey: 'like:$cardId');
      });

  Future<void> setSaved(int cardId, {required bool on}) =>
      _db.transaction(() async {
        await _db
            .into(_db.cardProgress)
            .insertOnConflictUpdate(
              CardProgressCompanion(cardId: Value(cardId), saved: Value(on)),
            );
        await _outbox.enqueue('save', {
          'card_id': cardId,
          'on': on,
        }, replaceKey: 'save:$cardId');
      });

  /// Saved cards (Profile), newest module first.
  Stream<List<FeedCard>> watchSaved() {
    final query =
        _db.select(_db.cardProgress).join([
            innerJoin(
              _db.cards,
              _db.cards.id.equalsExp(_db.cardProgress.cardId),
            ),
            innerJoin(
              _db.modules,
              _db.modules.id.equalsExp(_db.cards.moduleId),
            ),
          ])
          ..where(_db.cardProgress.saved.equals(true))
          ..orderBy([
            OrderingTerm.asc(_db.modules.id),
            OrderingTerm.asc(_db.cards.position),
          ]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          FeedCard(
            card: r.readTable(_db.cards),
            module: r.readTable(_db.modules),
            lessonPosition: 0,
            progress: r.readTable(_db.cardProgress),
          ),
      ],
    );
  }

  Stream<int> watchLessonsDone() => (_db.select(
    _db.lessonProgress,
  )..where((t) => t.completed.equals(true))).watch().map((rows) => rows.length);

  Stream<Map<String, int>> watchStudyDays() => _db
      .select(_db.studyDays)
      .watch()
      .map((rows) => {for (final r in rows) r.day: r.seconds});

  /// Live Continue source (same rule as LessonRepository.continueItems).
  Stream<List<ContinueItem>> watchContinue({int limit = 1}) {
    final query =
        _db.select(_db.readingPositions).join([
            innerJoin(
              _db.lessons,
              _db.lessons.id.equalsExp(_db.readingPositions.lessonId),
            ),
            innerJoin(
              _db.modules,
              _db.modules.id.equalsExp(_db.lessons.moduleId),
            ),
            leftOuterJoin(
              _db.lessonProgress,
              _db.lessonProgress.lessonId.equalsExp(
                _db.readingPositions.lessonId,
              ),
            ),
          ])
          ..where(
            _db.readingPositions.progress.isBetweenValues(0.02, 0.98) &
                (_db.lessonProgress.completed.isNull() |
                    _db.lessonProgress.completed.equals(false)),
          )
          ..orderBy([OrderingTerm.desc(_db.readingPositions.updatedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          ContinueItem(
            lesson: r.readTable(_db.lessons),
            module: r.readTable(_db.modules),
            position: r.readTable(_db.readingPositions),
          ),
      ],
    );
  }
}
