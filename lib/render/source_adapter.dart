/// Turns a SOURCE chapter (every text as {en, fr, ar}) into STUDENT blocks
/// for one language (CONTENT_FORMAT 4). Used by tests and the debug preview;
/// the server bundles already contain student blocks.
Object? localizeValue(Object? value, String lang) {
  if (value is Map) {
    final keys = value.keys;
    final isLangMap =
        keys.isNotEmpty &&
        keys.every((k) => k == 'en' || k == 'fr' || k == 'ar');
    if (isLangMap) {
      return localizeValue(
        value[lang] ?? value['fr'] ?? value.values.first,
        lang,
      );
    }
    return <String, dynamic>{
      for (final e in value.entries) '${e.key}': localizeValue(e.value, lang),
    };
  }
  if (value is List) return [for (final e in value) localizeValue(e, lang)];
  return value;
}

List<Map<String, dynamic>> blocksFromSourceChapter(
  Map<String, dynamic> source,
  String lang,
) {
  final out = <Map<String, dynamic>>[];
  final chapter = source['chapter'];
  if (chapter is! Map) return out;
  final sections = chapter['sections'];
  if (sections is! List) return out;
  for (final s in sections) {
    if (s is! Map) continue;
    final title = localizeValue(s['title'], lang);
    if (title is String && title.isNotEmpty) {
      out.add({
        'id': '${s['id'] ?? ''}',
        'type': 'heading',
        'content': title,
        'level': s['level'],
      });
    }
    final blocks = s['blocks'];
    if (blocks is! List) continue;
    for (final b in blocks) {
      final localized = localizeValue(b, lang);
      if (localized is Map<String, dynamic>) out.add(localized);
    }
  }
  return out;
}
