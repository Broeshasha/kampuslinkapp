import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// One row of get_notification_templates().
@immutable
class NotificationTemplate {
  const NotificationTemplate({
    required this.id,
    required this.kind,
    required this.lang,
    required this.title,
    required this.body,
    this.weight = 1,
  });

  factory NotificationTemplate.fromJson(Map<String, dynamic> j) =>
      NotificationTemplate(
        id: '${j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        lang: '${j['lang'] ?? ''}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        weight: j['weight'] is num ? (j['weight'] as num).toDouble() : 1,
      );

  final String id;
  final String kind;
  final String lang;
  final String title;
  final String body;
  final double weight;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'lang': lang,
    'title': title,
    'body': body,
    'weight': weight,
  };
}

List<NotificationTemplate> decodeTemplates(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  try {
    final v = jsonDecode(raw);
    return [
      if (v is List)
        for (final e in v)
          if (e is Map)
            NotificationTemplate.fromJson(e.cast<String, dynamic>()),
    ];
  } on FormatException {
    return const [];
  }
}

/// The local values a template can use. null = unknown (a template that
/// needs it is skipped).
@immutable
class TemplateValues {
  const TemplateValues({
    this.name,
    this.count,
    this.module,
    this.streak,
    this.minutes,
  });

  final String? name;
  final int? count;
  final String? module;
  final int? streak;
  final int? minutes;

  TemplateValues withModule(String? module) => TemplateValues(
    name: name,
    count: count,
    module: module,
    streak: streak,
    minutes: minutes,
  );
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// Fills {name} {count} {module} {streak} {minutes}. null when a
/// placeholder has no value (or is unknown): use another template.
/// In Arabic the French module name is isolated left-to-right.
String? fillTemplate(String text, TemplateValues v, {String lang = 'fr'}) {
  var missing = false;
  final out = text.replaceAllMapped(_placeholder, (m) {
    final String? value = switch (m.group(1)) {
      'name' => (v.name == null || v.name!.trim().isEmpty) ? null : v.name,
      'count' => v.count?.toString(),
      'module' =>
        v.module == null
            ? null
            : (lang == 'ar' ? '\u2066${v.module}\u2069' : v.module),
      'streak' => v.streak?.toString(),
      'minutes' => v.minutes?.toString(),
      _ => null,
    };
    if (value == null) {
      missing = true;
      return '';
    }
    return value;
  });
  return missing ? null : out;
}

/// Which kinds fit right now (lead brief: due_cards, new_lesson, streak,
/// generic, second_chance, exam_season).
List<String> fittingKinds({
  required bool secondChance,
  required int dueCount,
  required bool unreadLesson,
  required int streak,
  required bool examSeason,
  bool studiedToday = false,
}) {
  if (secondChance) {
    return const ['second_chance'];
  }
  if (studiedToday) {
    // Already studied today: "keep it going", never "you haven't studied".
    return [if (streak >= 2) 'streak', 'generic'];
  }
  return [
    if (dueCount > 0) 'due_cards',
    if (unreadLesson) 'new_lesson',
    if (streak >= 2) 'streak',
    if (examSeason) 'exam_season',
    'generic',
  ];
}

/// Weighted random among the templates of [kinds] in [lang] (French when
/// the language has none) whose placeholders all have values, never the
/// same body as [lastBody]. [valuesFor] gives the values of a kind (the
/// module of new_lesson differs from the one of due_cards).
({String title, String body, String kind})? pickTemplate({
  required List<NotificationTemplate> templates,
  required String lang,
  required List<String> kinds,
  required TemplateValues Function(String kind) valuesFor,
  required math.Random random,
  String? lastBody,
}) {
  final inLang = templates.where((t) => t.lang == lang).toList();
  final pool = inLang.isNotEmpty
      ? inLang
      : templates.where((t) => t.lang == 'fr').toList();
  final choices = <({String title, String body, String kind, double w})>[];
  for (final t in pool) {
    if (!kinds.contains(t.kind) || t.weight <= 0) {
      continue;
    }
    final language = t.lang;
    final values = valuesFor(t.kind);
    final title = fillTemplate(t.title, values, lang: language);
    final body = fillTemplate(t.body, values, lang: language);
    if (title == null || body == null || body == lastBody) {
      continue;
    }
    choices.add((title: title, body: body, kind: t.kind, w: t.weight));
  }
  if (choices.isEmpty) {
    return null;
  }
  final total = choices.fold<double>(0, (a, c) => a + c.w);
  var r = random.nextDouble() * total;
  for (final c in choices) {
    r -= c.w;
    if (r <= 0) {
      return (title: c.title, body: c.body, kind: c.kind);
    }
  }
  final last = choices.last;
  return (title: last.title, body: last.body, kind: last.kind);
}
