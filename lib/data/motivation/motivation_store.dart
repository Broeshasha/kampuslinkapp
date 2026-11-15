import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../learning/feed_repository.dart' show dayKey;
import 'prayer_times.dart';

/// MOT-1 (MOTIVATION_DESIGN.md). Everything here lives in the phone's
/// database (key_values): never uploaded, wiped with the other local data
/// when another student signs in. "My why" is never sent anywhere.
const _anchorKey = 'mot_anchor';
const _whyKey = 'mot_why';
const _daysKey = 'mot_days';
String _answersKey(String day) => 'mot_answers:$day';
String _targetKey(String day) => 'mot_target:$day';

/// Study anchors (implementation intention). Times are local wall clock;
/// all are before the 22:00 quiet hours.
enum StudyAnchor { afterSchool, afterMaghrib, afterIsha, afterDinner, beforeSleep, custom }

/// The reminder time of an anchor on [day] ("HH:mm"), null for custom.
String? anchorTime(StudyAnchor a, DateTime day) {
  String fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  DateTime cap(DateTime t) {
    final latest = DateTime(day.year, day.month, day.day, 21, 30);
    return t.isAfter(latest) ? latest : t;
  }

  final p = prayerTimes(day);
  return switch (a) {
    StudyAnchor.afterSchool => '17:00',
    StudyAnchor.afterMaghrib => fmt(cap(p.maghrib.add(const Duration(minutes: 20)))),
    StudyAnchor.afterIsha => fmt(cap(p.isha.add(const Duration(minutes: 20)))),
    StudyAnchor.afterDinner => '20:30',
    StudyAnchor.beforeSleep => '21:30',
    StudyAnchor.custom => null,
  };
}

/// Values the student can pick (1-2), shown back later. Codes only.
const whyValues = ['family', 'future_job', 'faith', 'prove_myself', 'scholarship', 'other'];

class MyWhy {
  const MyWhy({this.values = const [], this.text = ''});
  final List<String> values;
  final String text;
  bool get isEmpty => values.isEmpty && text.trim().isEmpty;
}

/// Today's Mission (~10 min): due cards (max 15) + one lesson step + a short
/// quiz (3 answers). Built from the phone only.
class MissionStatus {
  const MissionStatus({
    required this.day,
    required this.cardsTarget,
    required this.cardsDone,
    required this.lesson,
    required this.lessonDone,
    required this.quizLesson,
    required this.answers,
    required this.weekDays,
    required this.weekGoal,
    required this.weekStart,
    required this.missionDays,
    required this.weeksInRow,
  });

  static const quizTarget = 3;

  final String day;
  final int cardsTarget;
  final int cardsDone;

  /// Next lesson to read (null = nothing left / nothing downloaded).
  final LessonRow? lesson;
  final bool lessonDone;

  /// Lesson whose quiz is suggested (null = no quiz available).
  final LessonRow? quizLesson;
  final int answers;

  /// Days with a finished mission in the current week (Monday start).
  final int weekDays;
  final int weekGoal;
  final DateTime weekStart;
  final Set<String> missionDays;

  /// Weeks in a row (before this one) with the goal reached.
  final int weeksInRow;

  bool get cardsOk => cardsDone >= cardsTarget;
  bool get lessonOk => lessonDone || lesson == null;
  bool get quizOk => answers >= quizTarget || quizLesson == null;
  int get ticks => (cardsOk ? 1 : 0) + (lessonOk ? 1 : 0) + (quizOk ? 1 : 0);
  bool get done => ticks == 3;
  bool get weekReached => weekDays >= weekGoal;
}

DateTime weekStartOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Weeks in a row (ending the week before [now]) with >= [goal] days.
int weeksInRow(Set<String> days, DateTime now, int goal) {
  var week = weekStartOf(now).subtract(const Duration(days: 7));
  var n = 0;
  while (n < 520) {
    var count = 0;
    for (var i = 0; i < 7; i++) {
      if (days.contains(dayKey(week.add(Duration(days: i))))) count++;
    }
    if (count < goal) break;
    n++;
    week = week.subtract(const Duration(days: 7));
  }
  return n;
}

class MotivationStore {
  MotivationStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<String?> _get(String key) async => (await (_db.select(
    _db.keyValues,
  )..where((t) => t.name.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(value)),
      );

  // ---- anchor + why ----

  Future<StudyAnchor?> anchor() async {
    final v = await _get(_anchorKey);
    return StudyAnchor.values.where((a) => a.name == v).firstOrNull;
  }

  Future<void> setAnchor(StudyAnchor a) => _set(_anchorKey, a.name);

  Future<MyWhy> why() async {
    final raw = await _get(_whyKey);
    if (raw == null) return const MyWhy();
    try {
      final v = jsonDecode(raw);
      if (v is! Map) return const MyWhy();
      return MyWhy(
        values: [for (final x in v['values'] is List ? v['values'] as List : const []) '$x'],
        text: '${v['text'] ?? ''}',
      );
    } on FormatException {
      return const MyWhy();
    }
  }

  Future<void> setWhy(MyWhy why) => _set(
    _whyKey,
    jsonEncode({
      'values': why.values.where(whyValues.contains).take(2).toList(),
      'text': why.text.trim().length > 200 ? why.text.trim().substring(0, 200) : why.text.trim(),
    }),
  );

  // ---- mission ----

  /// One quiz answer given today (called inside the answer transaction).
  Future<void> countAnswer() async {
    final key = _answersKey(dayKey(_now()));
    final n = int.tryParse(await _get(key) ?? '') ?? 0;
    await _set(key, '${n + 1}');
  }

  Future<Set<String>> missionDays() async {
    final raw = await _get(_daysKey);
    if (raw == null) return {};
    try {
      final v = jsonDecode(raw);
      return v is List ? {for (final d in v) '$d'} : {};
    } on FormatException {
      return {};
    }
  }

  Future<bool> missionDoneOn(DateTime day) async =>
      (await missionDays()).contains(dayKey(day));

  /// Today's mission for the visible modules [moduleIds] (catalog order).
  Future<MissionStatus> today(List<int> moduleIds, {int weekGoal = 5}) async {
    final now = _now();
    final day = dayKey(now);
    final start = DateTime(now.year, now.month, now.day);

    // Cards: the target is fixed the first time today (due now, 5..15).
    var target = int.tryParse(await _get(_targetKey(day)) ?? '');
    if (target == null) {
      final cardCount = moduleIds.isEmpty
          ? 0
          : await (_db.selectOnly(_db.cards)
                  ..addColumns([_db.cards.id.count()])
                  ..where(_db.cards.moduleId.isIn(moduleIds)))
                .map((r) => r.read(_db.cards.id.count()) ?? 0)
                .getSingle();
      final due = moduleIds.isEmpty
          ? 0
          : await (_db.selectOnly(_db.cardProgress).join([
                  innerJoin(
                    _db.cards,
                    _db.cards.id.equalsExp(_db.cardProgress.cardId),
                    useColumns: false,
                  ),
                ])
                  ..addColumns([_db.cardProgress.cardId.count()])
                  ..where(
                    _db.cards.moduleId.isIn(moduleIds) &
                        _db.cardProgress.dueAt.isSmallerOrEqualValue(now),
                  ))
                .map((r) => r.read(_db.cardProgress.cardId.count()) ?? 0)
                .getSingle();
      target = cardCount == 0 ? 0 : due.clamp(5, 15);
      if (cardCount < target) target = cardCount;
      await _set(_targetKey(day), '$target');
    }
    final cardsDone = await (_db.selectOnly(_db.cardProgress)
          ..addColumns([_db.cardProgress.cardId.count()])
          ..where(_db.cardProgress.lastReviewedAt.isBiggerOrEqualValue(start)))
        .map((r) => r.read(_db.cardProgress.cardId.count()) ?? 0)
        .getSingle();

    // Lesson: first lesson not completed, modules in catalog order.
    final completed = {
      for (final p in await _db.select(_db.lessonProgress).get())
        if (p.completed) p.lessonId: p,
    };
    LessonRow? next;
    LessonRow? lastDone;
    DateTime? lastDoneAt;
    final lessonsByModule = <int, List<LessonRow>>{};
    if (moduleIds.isNotEmpty) {
      for (final l in await (_db.select(_db.lessons)
            ..where((t) => t.moduleId.isIn(moduleIds))
            ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.id)]))
          .get()) {
        lessonsByModule.putIfAbsent(l.moduleId, () => []).add(l);
      }
    }
    for (final m in moduleIds) {
      for (final l in lessonsByModule[m] ?? const <LessonRow>[]) {
        final p = completed[l.id];
        if (p == null) {
          next ??= l;
        } else if (lastDoneAt == null || (p.completedAt ?? start).isAfter(lastDoneAt)) {
          lastDone = l;
          lastDoneAt = p.completedAt ?? start;
        }
      }
    }
    final readToday = await (_db.select(_db.readingPositions)
          ..where((t) => t.updatedAt.isBiggerOrEqualValue(start) & t.progress.isBiggerOrEqualValue(0.5)))
        .get();
    final lessonDone =
        completed.values.any((p) => p.completedAt != null && !p.completedAt!.isBefore(start)) ||
        readToday.isNotEmpty;

    // Quiz: the last finished lesson with questions, else the next one.
    Future<bool> hasQuestions(LessonRow l) async =>
        (await (_db.select(_db.questions)
                  ..where((t) => t.lessonId.equals(l.id))
                  ..limit(1))
                .get())
            .isNotEmpty;
    LessonRow? quizLesson;
    if (lastDone != null && await hasQuestions(lastDone)) {
      quizLesson = lastDone;
    } else if (next != null && await hasQuestions(next)) {
      quizLesson = next;
    }
    final answers = int.tryParse(await _get(_answersKey(day)) ?? '') ?? 0;

    final days = await missionDays();
    final week = weekStartOf(now);
    var status = MissionStatus(
      day: day,
      cardsTarget: target,
      cardsDone: cardsDone,
      lesson: next,
      lessonDone: lessonDone,
      quizLesson: quizLesson,
      answers: answers,
      weekDays: 0,
      weekGoal: weekGoal,
      weekStart: week,
      missionDays: days,
      weeksInRow: weeksInRow(days, now, weekGoal),
    );
    // A finished mission marks the day (kept for a year).
    if (status.done && !days.contains(day) && moduleIds.isNotEmpty) {
      days.add(day);
      final keep = days.where((d) => d.compareTo(dayKey(now.subtract(const Duration(days: 400)))) >= 0).toList()..sort();
      await _set(_daysKey, jsonEncode(keep));
    }
    var inWeek = 0;
    for (var i = 0; i < 7; i++) {
      if (days.contains(dayKey(week.add(Duration(days: i))))) inWeek++;
    }
    status = MissionStatus(
      day: day,
      cardsTarget: target,
      cardsDone: cardsDone,
      lesson: next,
      lessonDone: lessonDone,
      quizLesson: quizLesson,
      answers: answers,
      weekDays: inWeek,
      weekGoal: weekGoal,
      weekStart: week,
      missionDays: days,
      weeksInRow: status.weeksInRow,
    );
    return status;
  }
}
