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
  });

  factory CaseSlide.fromMap(Map<String, dynamic> m) => CaseSlide(
    id: _s(m['id']),
    role: _role(m['role']),
    title: _s(m['title']),
    content: _s(m['content']),
    highlights: _l(m['highlights']),
    prompt: _s(m['prompt']),
    options: [for (final o in _l(m['options'])) _s(o)],
    correctIndex: m['correct_index'] is num
        ? (m['correct_index'] as num).toInt()
        : null,
    explanation: _s(m['explanation']),
  );

  final String id;
  final SlideRole role;
  final String title;
  final String content;
  final List<Object?> highlights;
  final String prompt;
  final List<String> options;
  final int? correctIndex;
  final String explanation;
}

/// A carousel set (lead brief B3): 3-8 slides read left to right.
class CaseSet {
  const CaseSet({
    required this.id,
    required this.title,
    required this.language,
    required this.slides,
  });

  /// [source] has every text as {en, fr, ar}; [lang] falls back to French.
  factory CaseSet.fromSource(Map<String, Object?> source, String lang) {
    final m = localizeValue(source, lang);
    final map = m is Map<String, dynamic> ? m : const <String, dynamic>{};
    return CaseSet(
      id: _s(map['id']),
      title: _s(map['title']),
      language: lang,
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
  );

  final String setId;
  final int reached;
  final int? guess;
  final Map<String, int> answers;
  final bool finished;

  bool get started => reached > 0 || guess != null;

  Map<String, dynamic> toJson() => {
    'set_id': setId,
    'reached': reached,
    'guess': guess,
    'answers': answers,
    'finished': finished,
  };

  CaseProgress copyWith({
    int? reached,
    int? guess,
    Map<String, int>? answers,
    bool? finished,
  }) => CaseProgress(
    setId: setId,
    reached: reached ?? this.reached,
    guess: guess ?? this.guess,
    answers: answers ?? this.answers,
    finished: finished ?? this.finished,
  );
}
