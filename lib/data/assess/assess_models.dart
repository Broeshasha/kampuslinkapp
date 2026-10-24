import '../lessons/figures.dart' show figureMap;

/// Contract file 15 (practice + mock exams). Every reader here is tolerant:
/// a text may be a language map or a plain string, a text list may come
/// as a map of lists, ids are strings, points may be decimals, unknown
/// keys are ignored and a missing field never throws.

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
String _s(Object? v) => v == null ? '' : '$v';
int _int(Object? v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;

/// T: {en, fr, ar} (or a plain string) in [lang], then French, then any.
String pickText(Object? v, String lang) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is num) return '$v';
  if (v is Map) {
    if (v.isEmpty) return '';
    final t = v[lang] ?? v['fr'] ?? v.values.first;
    return t is String ? t : (t == null ? '' : '$t');
  }
  return '';
}

/// T-list: a list of T, or one map of lists {en: [..], fr: [..]}, or a
/// single T (one item). Empty entries are dropped.
List<String> pickTextList(Object? v, String lang) {
  if (v == null) return const [];
  if (v is List) {
    return [
      for (final e in v)
        if (pickText(e, lang) case final t when t.trim().isNotEmpty) t,
    ];
  }
  if (v is Map && v.values.any((x) => x is List)) {
    final picked = v[lang] ?? v['fr'] ?? v.values.firstWhere((x) => x is List);
    return pickTextList(picked, lang);
  }
  final one = pickText(v, lang);
  return one.trim().isEmpty ? const [] : [one];
}

/// First present key of [keys] in [m].
Object? _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) return v;
  }
  return null;
}

/// A lesson-style table block (or null when the shape is unknown).
Map<String, dynamic>? tableOf(Object? v) {
  if (v is! Map) return null;
  final m = v.cast<String, dynamic>();
  if (m['rows'] is! List && m['columns'] is! List) return null;
  return {'type': 'table', ...m};
}

/// A code solution (994 Python): solution_code + solution_output.
class CodeSolution {
  const CodeSolution(this.code, this.output);

  final String code;
  final String output;
}

CodeSolution? _code(Map<String, dynamic> m, String lang) {
  final code = pickText(m['solution_code'], lang);
  if (code.trim().isEmpty) return null;
  return CodeSolution(code, pickText(m['solution_output'], lang));
}

class PracticePart {
  const PracticePart({
    required this.id,
    required this.prompt,
    this.hints = const [],
    this.steps = const [],
    this.answer = '',
    this.figure,
    this.code,
  });

  factory PracticePart.fromMap(Map<String, dynamic> m, String lang) =>
      PracticePart(
        id: _s(m['id']),
        prompt: pickText(_first(m, ['prompt', 'question', 'statement']), lang),
        hints: pickTextList(m['hints'], lang),
        steps: pickTextList(
          _first(m, ['solution_steps', 'steps', 'solution']),
          lang,
        ),
        answer: pickText(_first(m, ['final_answer', 'answer']), lang),
        figure: figureMap(m['figure']),
        code: _code(m, lang),
      );

  final String id;
  final String prompt;
  final List<String> hints;
  final List<String> steps;
  final String answer;
  final Map<String, dynamic>? figure;
  final CodeSolution? code;
}

class PracticeItem {
  const PracticeItem({
    required this.id,
    required this.chapterRef,
    required this.unitNumber,
    required this.position,
    required this.title,
    required this.statement,
    this.difficulty,
    this.figure,
    this.table,
    this.parts = const [],
  });

  factory PracticeItem.fromMap(Map<String, dynamic> m, String lang) {
    final d = m['difficulty'];
    return PracticeItem(
      id: _int(m['id']),
      chapterRef: _s(m['chapter_ref']),
      unitNumber: _int(m['unit_number']),
      position: _int(m['position']),
      difficulty: d is num ? d.toInt() : null,
      title: pickText(m['title'], lang),
      statement: pickText(m['statement'], lang),
      figure: figureMap(m['figure']),
      table: tableOf(m['table']),
      parts: [
        for (final p in _list(m['parts']))
          if (p is Map) PracticePart.fromMap(p.cast<String, dynamic>(), lang),
      ],
    );
  }

  final int id;
  final String chapterRef;
  final int unitNumber;
  final int position;
  final int? difficulty;
  final String title;
  final String statement;
  final Map<String, dynamic>? figure;
  final Map<String, dynamic>? table;
  final List<PracticePart> parts;
}

/// One marking line: points may be null (text only).
class MarkingLine {
  const MarkingLine(this.points, this.criterion);

  final double? points;
  final String criterion;
}

List<MarkingLine> _marking(Object? v, String lang) {
  final out = <MarkingLine>[];
  for (final e in _list(v)) {
    if (e is Map && (e.containsKey('criterion') || e.containsKey('points'))) {
      final p = e['points'];
      out.add(
        MarkingLine(
          p is num ? p.toDouble() : double.tryParse(_s(p)),
          pickText(e['criterion'] ?? e['text'], lang),
        ),
      );
    } else {
      // Converted papers: plain text lines.
      final t = pickText(e, lang);
      if (t.trim().isNotEmpty) out.add(MarkingLine(null, t));
    }
  }
  return out;
}

class ExamPart {
  const ExamPart({
    required this.id,
    required this.points,
    required this.prompt,
    this.steps = const [],
    this.answer = '',
    this.marking = const [],
    this.figure,
    this.code,
  });

  factory ExamPart.fromMap(Map<String, dynamic> m, String lang) => ExamPart(
    id: _s(m['id']),
    points: _num(m['points']),
    prompt: pickText(_first(m, ['prompt', 'question', 'statement']), lang),
    steps: pickTextList(
      _first(m, ['solution_steps', 'steps', 'solution']),
      lang,
    ),
    answer: pickText(_first(m, ['final_answer', 'answer']), lang),
    marking: _marking(m['marking'], lang),
    figure: figureMap(m['figure']),
    code: _code(m, lang),
  );

  final String id;
  final double points;
  final String prompt;
  final List<String> steps;
  final String answer;
  final List<MarkingLine> marking;

  /// Solution diagram: correction mode only.
  final Map<String, dynamic>? figure;
  final CodeSolution? code;
}

class ExamExercise {
  const ExamExercise({
    required this.id,
    required this.points,
    this.title = '',
    this.statement = '',
    this.figure,
    this.table,
    this.parts = const [],
  });

  factory ExamExercise.fromMap(Map<String, dynamic> m, String lang) =>
      ExamExercise(
        id: _s(m['id']),
        points: _num(m['points']),
        title: pickText(m['title'], lang),
        statement: pickText(m['statement'], lang),
        figure: figureMap(m['figure']),
        table: tableOf(m['table']),
        parts: [
          // Always "parts"; old copies under questions/sections are ignored.
          for (final p in _list(m['parts']))
            if (p is Map) ExamPart.fromMap(p.cast<String, dynamic>(), lang),
        ],
      );

  final String id;
  final double points;
  final String title;
  final String statement;
  final Map<String, dynamic>? figure;
  final Map<String, dynamic>? table;
  final List<ExamPart> parts;
}

class ExamPaper {
  const ExamPaper({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.durationMin,
    required this.totalPoints,
    this.position = 0,
    this.instructions = '',
    this.exercises = const [],
  });

  factory ExamPaper.fromMap(Map<String, dynamic> m, String lang) => ExamPaper(
    id: _int(m['id']),
    moduleId: _int(m['module_id']),
    position: _int(m['position']),
    title: pickText(m['title'], lang),
    instructions: pickText(m['instructions'], lang),
    durationMin: _int(m['duration_min']),
    totalPoints: _num(m['total_points']),
    exercises: [
      for (final e in _list(m['exercises']))
        if (e is Map) ExamExercise.fromMap(e.cast<String, dynamic>(), lang),
    ],
  );

  final int id;
  final int moduleId;
  final int position;
  final String title;
  final String instructions;
  final int durationMin;
  final double totalPoints;
  final List<ExamExercise> exercises;

  /// "ex1/a" -> part points (the max a student can enter).
  Map<String, double> get maxByKey => {
    for (final e in exercises)
      for (final p in e.parts) scoreKey(e.id, p.id): p.points,
  };
}

String scoreKey(String exerciseId, String partId) => '$exerciseId/$partId';

/// A header from the manifest ("exams": [...]): enough for the list.
class ExamHeader {
  const ExamHeader({
    required this.id,
    required this.title,
    required this.durationMin,
    required this.totalPoints,
    required this.position,
    required this.rev,
  });

  factory ExamHeader.fromMap(Map<String, dynamic> m, String lang) => ExamHeader(
    id: _int(m['id']),
    title: pickText(m['title'], lang),
    durationMin: _int(m['duration_min']),
    totalPoints: _num(m['total_points']),
    position: _int(m['position']),
    rev: _s(m['rev']),
  );

  final int id;
  final String title;
  final int durationMin;
  final double totalPoints;
  final int position;
  final String rev;
}

enum AttemptStatus { inProgress, finished, abandoned }

AttemptStatus attemptStatusOf(Object? v) => switch (_s(v)) {
  'finished' => AttemptStatus.finished,
  'abandoned' => AttemptStatus.abandoned,
  _ => AttemptStatus.inProgress,
};

String attemptStatusName(AttemptStatus s) => switch (s) {
  AttemptStatus.inProgress => 'in_progress',
  AttemptStatus.finished => 'finished',
  AttemptStatus.abandoned => 'abandoned',
};

/// One mock exam attempt (local copy of the server row).
class ExamAttempt {
  const ExamAttempt({
    required this.attemptId,
    required this.paperId,
    required this.status,
    required this.startedAt,
    required this.at,
    this.finishedAt,
    this.scores = const {},
  });

  factory ExamAttempt.fromMap(Map<String, dynamic> m) => ExamAttempt(
    attemptId: _s(m['attempt_id']),
    paperId: _int(m['paper_id']),
    status: attemptStatusOf(m['status']),
    startedAt: DateTime.tryParse(_s(m['started_at'])) ?? DateTime(2000),
    finishedAt: DateTime.tryParse(_s(m['finished_at'])),
    at:
        DateTime.tryParse(_s(m['at'] ?? m['updated_at'])) ??
        DateTime.tryParse(_s(m['started_at'])) ??
        DateTime(2000),
    scores: {
      for (final e in _map(m['scores']).entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    },
  );

  final String attemptId;
  final int paperId;
  final AttemptStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DateTime at;
  final Map<String, double> scores;

  /// The sync op payload: the WHOLE scores map every time.
  Map<String, Object?> toPayload() => {
    'attempt_id': attemptId,
    'paper_id': paperId,
    'status': attemptStatusName(status),
    'started_at': startedAt.toUtc().toIso8601String(),
    'finished_at': finishedAt?.toUtc().toIso8601String(),
    'at': at.toUtc().toIso8601String(),
    'scores': scores,
  };

  ExamAttempt copyWith({
    AttemptStatus? status,
    DateTime? finishedAt,
    DateTime? at,
    Map<String, double>? scores,
  }) => ExamAttempt(
    attemptId: attemptId,
    paperId: paperId,
    status: status ?? this.status,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    at: at ?? this.at,
    scores: scores ?? this.scores,
  );
}

/// Points rounded to the 0.25 grid and clamped to 0..max.
double clampPoints(double v, double max) {
  final q = (v * 4).roundToDouble() / 4;
  return q < 0 ? 0 : (q > max ? max : q);
}

/// Same rule as the server: unknown keys dropped, each score clamped.
double attemptTotal(Map<String, double> scores, Map<String, double> maxByKey) {
  var total = 0.0;
  for (final e in scores.entries) {
    final max = maxByKey[e.key];
    if (max == null) continue;
    total += clampPoints(e.value, max);
  }
  return total;
}

double score20(double total, double totalPoints) =>
    totalPoints <= 0 ? 0 : total * 20 / totalPoints;

/// A score with at most 2 decimals and no trailing zeros ("12.5", "7").
String formatPoints(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}
