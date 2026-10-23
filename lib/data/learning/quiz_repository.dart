import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../lessons/figures.dart';
import '../lessons/lesson_content.dart';
import '../sync/outbox_repository.dart';
import 'progress_repository.dart';

/// One question in one language.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.correctIndex,
    required this.prompt,
    required this.options,
    required this.explanation,
    required this.language,
    this.figure,
    this.optionFigures = const [],
  });

  final int id;
  final String kind;
  final int correctIndex;
  final String prompt;
  final List<String> options;
  final String explanation;
  final String language;

  /// WP16 B: optional diagram, and one per option (null = none).
  final Map<String, dynamic>? figure;
  final List<Map<String, dynamic>?> optionFigures;
}

String _quizKey(int lessonId) => 'quiz:$lessonId';

/// Lesson quizzes, offline: every answer is saved on the phone at once
/// (an interrupted quiz resumes at the first unanswered question) and
/// queued for the server. A wrong answer brings the lesson's cards back
/// into the feed, like the server's submit_answer().
class QuizRepository {
  QuizRepository(
    this._db,
    this._outbox,
    this._progress, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final ProgressRepository _progress;
  final DateTime Function() _now;

  Future<int> questionCount(int lessonId) async {
    final rows = await (_db.select(
      _db.questions,
    )..where((t) => t.lessonId.equals(lessonId))).get();
    return rows.length;
  }

  Future<List<QuizQuestion>> questions(int lessonId, String wanted) async {
    final rows =
        await (_db.select(_db.questions)
              ..where((t) => t.lessonId.equals(lessonId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final metaRow = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals('meta:$lessonId'))).getSingleOrNull();
    var meta = const <String, dynamic>{};
    if (metaRow != null) {
      try {
        final v = jsonDecode(metaRow.value);
        final qs = v is Map ? v['q'] : null;
        if (qs is Map) meta = qs.cast<String, dynamic>();
      } on FormatException {
        meta = const {};
      }
    }
    final out = <QuizQuestion>[];
    for (final q in rows) {
      Map<String, dynamic> i18n;
      try {
        final v = jsonDecode(q.i18nJson);
        i18n = v is Map ? v.cast<String, dynamic>() : const {};
      } on FormatException {
        i18n = const {};
      }
      final lang = pickLanguage(i18n.keys, wanted);
      final t = i18n[lang];
      final m = t is Map
          ? t.cast<String, dynamic>()
          : const <String, dynamic>{};
      final options = m['options'];
      final shared = meta['${q.id}'];
      final sharedMap = shared is Map ? shared : const <String, dynamic>{};
      final optionCount = options is List ? options.length : 0;
      out.add(
        QuizQuestion(
          id: q.id,
          kind: q.kind,
          correctIndex: q.correctIndex,
          prompt: '${m['prompt'] ?? ''}',
          options: options is List
              ? [for (final o in options) '$o']
              : const <String>[],
          explanation: '${m['explanation'] ?? ''}',
          language: lang,
          figure: pickFigure(text: m, shared: sharedMap['figure']),
          optionFigures: pickOptionFigures(
            text: m,
            shared: sharedMap['option_figures'],
            count: optionCount,
          ),
        ),
      );
    }
    return out;
  }

  /// question id -> chosen option, for the quiz in progress.
  Future<Map<int, int>> savedAnswers(int lessonId) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals(_quizKey(lessonId)))).getSingleOrNull();
    if (row == null) return {};
    try {
      final v = jsonDecode(row.value);
      if (v is! Map) return {};
      return {
        for (final e in v.entries)
          if (int.tryParse('${e.key}') != null && e.value is num)
            int.parse('${e.key}'): (e.value as num).toInt(),
      };
    } on FormatException {
      return {};
    }
  }

  /// Saves the answer locally + queues it. Returns true when correct.
  Future<bool> answer(int lessonId, QuizQuestion question, int choice) =>
      _db.transaction(() async {
        final answers = await savedAnswers(lessonId);
        answers[question.id] = choice;
        await _db
            .into(_db.keyValues)
            .insertOnConflictUpdate(
              KeyValuesCompanion(
                name: Value(_quizKey(lessonId)),
                value: Value(
                  jsonEncode({
                    for (final e in answers.entries) '${e.key}': e.value,
                  }),
                ),
              ),
            );
        await _outbox.enqueue('answer', {
          'question_id': question.id,
          'choice': choice,
        });
        final correct = choice == question.correctIndex;
        if (!correct) {
          final now = _now();
          final cards = await (_db.select(
            _db.cards,
          )..where((t) => t.lessonId.equals(lessonId))).get();
          for (final c in cards) {
            await _db
                .into(_db.cardProgress)
                .insertOnConflictUpdate(
                  CardProgressCompanion(
                    cardId: Value(c.id),
                    box: const Value(1),
                    dueAt: Value(now),
                  ),
                );
          }
        }
        return correct;
      });

  /// Quiz finished: lesson done with its score (0-100), progress cleared.
  Future<void> finish(int lessonId, int score) async {
    await _progress.completeLesson(lessonId, score: score);
    await (_db.delete(
      _db.keyValues,
    )..where((t) => t.name.equals(_quizKey(lessonId)))).go();
  }
}
