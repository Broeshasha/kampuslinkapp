import 'dart:convert';

/// WP16 B: optional figures on cards, questions and options. Shape (like a
/// carousel slide figure): {asset: {type: svg, svg, width?, height?, alt?},
/// caption?}. alt and caption may be a String or {en, fr, ar}. A figure can
/// sit on the item (shared by every language) or inside one language's
/// text; the language one wins.
Map<String, dynamic>? figureMap(Object? v) {
  if (v is! Map) return null;
  final m = v.cast<String, dynamic>();
  if (m['asset'] is Map) return m;
  if (m['svg'] is String) {
    return {
      ...m,
      'asset': {'type': 'svg', 'svg': m['svg'], 'alt': ?m['alt']},
    };
  }
  return null;
}

/// The text of [v] in [lang] (String, or a map by language: wanted, then
/// French, then English, then any).
String figureText(Object? v, String lang) {
  if (v is String) return v;
  if (v is! Map || v.isEmpty) return '';
  final t = v[lang] ?? v['fr'] ?? v['en'] ?? v.values.first;
  return t == null ? '' : '$t';
}

/// One language's text map of an item's i18n json ({} when missing).
Map<String, dynamic> langText(String i18nJson, String lang) {
  try {
    final v = jsonDecode(i18nJson);
    final t = v is Map ? v[lang] : null;
    return t is Map ? t.cast<String, dynamic>() : const <String, dynamic>{};
  } on FormatException {
    return const <String, dynamic>{};
  }
}

Map<String, dynamic>? pickFigure({
  Map<String, dynamic>? text,
  Object? shared,
}) => figureMap(text?['figure']) ?? figureMap(shared);

/// One figure (or null) per option; empty when no option has one.
List<Map<String, dynamic>?> pickOptionFigures({
  Map<String, dynamic>? text,
  Object? shared,
  required int count,
}) {
  final raw = text?['option_figures'] ?? shared;
  if (raw is! List || count <= 0) return const [];
  final out = [
    for (var i = 0; i < count; i++) i < raw.length ? figureMap(raw[i]) : null,
  ];
  return out.any((f) => f != null) ? out : const [];
}
