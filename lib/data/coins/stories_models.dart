import 'package:flutter/painting.dart' show Color;

import 'coins_models.dart';

/// Colours, texts and timing of one story type (kl_story_templates).
class StoryTemplate {
  const StoryTemplate({
    required this.type,
    this.name,
    this.cta,
    this.icon,
    this.bg = const Color(0xFF3B3FD9),
    this.fg = const Color(0xFFFFFFFF),
    this.accent = const Color(0xFFFFD43B),
    this.durationMs = 7000,
    this.interactive = false,
  });

  factory StoryTemplate.fromMap(String type, Map<String, dynamic> m) {
    final c = asMap(m['colors']);
    final ms = asInt(m['duration_ms']);
    return StoryTemplate(
      type: type,
      name: m['name'],
      cta: m['cta'],
      icon: m['icon'] is String ? m['icon'] as String : null,
      bg: parseHexColor(c['bg']) ?? const Color(0xFF3B3FD9),
      fg: parseHexColor(c['fg']) ?? const Color(0xFFFFFFFF),
      accent: parseHexColor(c['accent']) ?? const Color(0xFFFFD43B),
      durationMs: ms >= 2000 ? ms : 7000,
      interactive: m['interactive'] == true,
    );
  }

  final String type;
  final Object? name;
  final Object? cta;
  final String? icon;
  final Color bg, fg, accent;
  final int durationMs;
  final bool interactive;
}

/// One story of get_my_stories().
class Story {
  const Story({
    required this.key,
    required this.source,
    required this.template,
    required this.payload,
    this.expiresAt,
    this.seen = false,
    this.answeredChoice,
    this.answeredCorrect,
  });

  factory Story.fromMap(Map<String, dynamic> m) {
    final a = m['answered'];
    return Story(
      key: '${m['key']}',
      source: '${m['source'] ?? 'auto'}',
      template: '${m['template']}',
      payload: asMap(m['payload']),
      expiresAt: DateTime.tryParse('${m['expires_at'] ?? ''}'),
      seen: m['seen'] == true,
      answeredChoice: a is Map ? asInt(a['choice']) : null,
      answeredCorrect: a is Map ? a['is_correct'] == true : null,
    );
  }

  final String key;

  /// 'auto' (personal, every morning) or 'editorial'.
  final String source;
  final String template;
  final Map<String, dynamic> payload;
  final DateTime? expiresAt;
  final bool seen;
  final int? answeredChoice;
  final bool? answeredCorrect;

  /// A question story: it carries its right answer and its texts.
  bool get isQuestion =>
      payload['correct_index'] is num && payload['i18n'] is Map;

  int get correctIndex => asInt(payload['correct_index']);

  int get moduleId => asInt(asMap(payload['module'])['id']);

  int? get lessonId =>
      payload['lesson_id'] is num ? asInt(payload['lesson_id']) : null;

  Story copyWith({bool? seen, int? answeredChoice, bool? answeredCorrect}) =>
      Story(
        key: key,
        source: source,
        template: template,
        payload: payload,
        expiresAt: expiresAt,
        seen: seen ?? this.seen,
        answeredChoice: answeredChoice ?? this.answeredChoice,
        answeredCorrect: answeredCorrect ?? this.answeredCorrect,
      );
}

class StoriesData {
  const StoriesData({
    this.day = '',
    this.balance = 0,
    this.templates = const <String, StoryTemplate>{},
    this.stories = const <Story>[],
  });

  factory StoriesData.fromMap(Map<String, dynamic> m) {
    final t = asMap(m['templates']);
    return StoriesData(
      day: '${m['day'] ?? ''}',
      balance: asInt(m['balance']),
      templates: {
        for (final e in t.entries)
          e.key: StoryTemplate.fromMap(e.key, asMap(e.value)),
      },
      stories: [
        for (final s in asList(m['stories']))
          if (s is Map) Story.fromMap(s.cast<String, dynamic>()),
      ],
    );
  }

  final String day;
  final int balance;
  final Map<String, StoryTemplate> templates;
  final List<Story> stories;

  StoriesData withStories(List<Story> next) => StoriesData(
    day: day,
    balance: balance,
    templates: templates,
    stories: next,
  );

  StoryTemplate templateOf(String type) =>
      templates[type] ?? StoryTemplate(type: type);
}

/// A circle of the stories bar: the personal stories of the day together,
/// every editorial story on its own.
class StoryGroup {
  const StoryGroup(this.id, this.stories);

  final String id;
  final List<Story> stories;

  bool get isToday => id == 'today';
  bool get allSeen => stories.every((s) => s.seen);
  Story get lead => stories.first;
}

List<StoryGroup> groupStories(List<Story> stories) {
  final today = [
    for (final s in stories)
      if (s.source == 'auto') s,
  ];
  return [
    if (today.isNotEmpty) StoryGroup('today', today),
    for (final s in stories)
      if (s.source != 'auto') StoryGroup(s.key, [s]),
  ];
}

/// What the phone knows right after an answer. [coins] is what the SERVER
/// paid (null = not known yet because the phone is offline).
class StoryOutcome {
  const StoryOutcome({required this.correct, this.coins});

  final bool correct;
  final int? coins;
}
