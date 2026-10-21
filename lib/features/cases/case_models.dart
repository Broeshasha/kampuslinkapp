import '../../render/source_adapter.dart';

enum SlideRole { hook, clue, step, commit, reveal, quiz, takeaway, unknown }

SlideRole _role(Object? v) => switch ('$v') {
  'hook' => SlideRole.hook,
  'clue' => SlideRole.clue,
  'step' => SlideRole.step,
  'commit' => SlideRole.commit,
  'reveal' => SlideRole.reveal,
  'quiz' => SlideRole.quiz,
  'takeaway' => SlideRole.takeaway,
  _ => SlideRole.unknown,
};

String _s(Object? v) => v == null ? '' : '$v';
List<Object?> _l(Object? v) => v is List ? v : const <Object?>[];
int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Server sets may keep their texts under i18n[lang] (already localized by
/// localizeValue): lift them to the top level, structure fields stay.
Map<String, dynamic> _lift(Object? v) {
  if (v is! Map) return const <String, dynamic>{};
  final m = v.cast<String, dynamic>();
  final i18n = m['i18n'];
  if (i18n is! Map) return m;
  return {...m, ...i18n.cast<String, dynamic>()}..remove('i18n');
}

/// Kinds of carousel sets (lead brief 2, D).
enum CaseKind { mystery, explainer, quizChain, other }

CaseKind _kind(Object? v) => switch ('$v') {
  'mystery' => CaseKind.mystery,
  'explainer' => CaseKind.explainer,
  'quiz_chain' => CaseKind.quizChain,
  _ => CaseKind.other,
};

/// One slide of a carousel set, already in one language.
class CaseSlide {
  const CaseSlide({
    required this.id,
    required this.role,
    this.title = '',
    this.content = '',
    this.highlights = const <Object?>[],
    this.prompt = '',
    this.options = const <String>[],
    this.correctIndex,
    this.explanation = '',
    this.examNote = '',
    this.figure,
  });

  factory CaseSlide.fromMap(Map<String, dynamic> raw) {
    final m = _lift(raw);
    final fig = m['figure'];
    Map<String, dynamic>? figure;
    if (fig is Map) {
      final f = fig.cast<String, dynamic>();
      final asset = f['asset'] is Map
          ? (f['asset'] as Map).cast<String, dynamic>()
          : <String, dynamic>{'type': 'svg', 'svg': f['svg'] ?? ''};
      figure = {
        'type': 'figure',
        'asset': asset,
        if (f['caption'] != null) 'caption': f['caption'],
      };
    } else if (m['svg'] != null) {
      figure = {
        'type': 'figure',
        'asset': {'type': 'svg', 'svg': m['svg']},
      };
    }
    return CaseSlide(
      id: _s(m['id']),
      role: _role(m['role'] ?? m['type']),
      title: _s(m['title']),
      content: _s(m['content'] ?? m['body'] ?? m['text']),
      highlights: _l(m['highlights']),
      prompt: _s(m['prompt'] ?? m['question']),
      options: [for (final o in _l(m['options'])) _s(o)],
      correctIndex: _i(m['correct_index']),
      explanation: _s(m['explanation']),
      examNote: _s(m['exam_note'] ?? m['why_exam'] ?? m['exam']),
      figure: figure,
    );
  }

  final String id;
  final SlideRole role;
  final String title;
  final String content;
  final List<Object?> highlights;
  final String prompt;
  final List<String> options;
  final int? correctIndex;
  final String explanation;

  /// "Why this matters for the exam" (reveal), optional.
  final String examNote;

  /// A figure block ({type: figure, asset: {type: svg, svg}}), optional.
  final Map<String, dynamic>? figure;
}

/// A carousel set (lead brief B3): 3-8 slides read left to right.
class CaseSet {
  const CaseSet({
    required this.id,
    required this.title,
    required this.language,
    required this.slides,
    this.kind = CaseKind.other,
    this.moduleId,
    this.lessonId,
    this.position = 0,
  });

  /// [source] has every text as {en, fr, ar} (or under i18n[lang]);
  /// [lang] falls back to French, then to any language.
  factory CaseSet.fromSource(Map<String, Object?> source, String lang) {
    final map = _lift(localizeValue(source, lang));
    return CaseSet(
      id: _s(map['id']),
      title: _s(map['title']),
      language: lang,
      kind: _kind(map['kind']),
      moduleId: _i(map['module_id']),
      lessonId: _i(map['lesson_id']),
      position: _i(map['position']) ?? 0,
      slides: [
        for (final s in _l(map['slides']))
          if (s is Map) CaseSlide.fromMap(s.cast<String, dynamic>()),
      ],
    );
  }

  final String id;
  final String title;
  final String language;
  final List<CaseSlide> slides;
  final CaseKind kind;
  final int? moduleId;
  final int? lessonId;
  final int position;

  /// Index of the "commit" slide (the student locks a guess), or -1.
  int get commitIndex => slides.indexWhere((s) => s.role == SlideRole.commit);

  CaseSlide? get commitSlide => commitIndex < 0 ? null : slides[commitIndex];
}

/// Progress on one set: furthest slide, locked guess, quick-check answers.
class CaseProgress {
  const CaseProgress({
    required this.setId,
    this.reached = 0,
    this.guess,
    this.answers = const <String, int>{},
    this.finished = false,
    this.correct,
    this.saved = false,
  });

  factory CaseProgress.fromJson(Map<String, dynamic> j) => CaseProgress(
    setId: _s(j['set_id']),
    reached: j['reached'] is num ? (j['reached'] as num).toInt() : 0,
    guess: j['guess'] is num ? (j['guess'] as num).toInt() : null,
    answers: {
      if (j['answers'] is Map)
        for (final e in (j['answers'] as Map).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
    },
    finished: j['finished'] == true,
    correct: j['correct'] is bool ? j['correct'] as bool : null,
    saved: j['saved'] == true,
  );

  final String setId;
  final int reached;
  final int? guess;
  final Map<String, int> answers;
  final bool finished;

  /// The locked guess was right (null = no guess yet).
  final bool? correct;
  final bool saved;

  bool get started => reached > 0 || guess != null;

  Map<String, dynamic> toJson() => {
    'set_id': setId,
    'reached': reached,
    'guess': guess,
    'answers': answers,
    'finished': finished,
    'correct': correct,
    'saved': saved,
  };

  CaseProgress copyWith({
    int? reached,
    int? guess,
    Map<String, int>? answers,
    bool? finished,
    bool? correct,
    bool? saved,
  }) => CaseProgress(
    setId: setId,
    reached: reached ?? this.reached,
    guess: guess ?? this.guess,
    answers: answers ?? this.answers,
    finished: finished ?? this.finished,
    correct: correct ?? this.correct,
    saved: saved ?? this.saved,
  );
}
