/// CDN files carry every language. These functions keep only the requested
/// ones, the same way the server does for the Supabase downloads
/// (_filter_langs_deep, _lesson_json, get_module_extras, _practice_json,
/// get_exam_paper), so both sources give the importer the same shape.
library;

const _langCodes = {'en', 'fr', 'ar'};

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// A {lang: value} object: only the requested languages stay.
Object? filterLangs(Object? j, List<String> langs) {
  if (j is! Map) return j;
  return <String, dynamic>{
    for (final e in j.entries)
      if (langs.contains('${e.key}')) '${e.key}': e.value,
  };
}

/// Same rule as the server's _filter_langs_deep: an object with 2 or 3 keys
/// that are all language codes is a language map (filtered, not entered);
/// every other object and every array is walked.
Object? filterLangsDeep(Object? j, List<String> langs) {
  if (j is Map) {
    final isLangMap =
        j.length >= 2 &&
        j.length <= 3 &&
        j.keys.every((k) => _langCodes.contains('$k'));
    if (isLangMap) return filterLangs(j, langs);
    return <String, dynamic>{
      for (final e in j.entries) '${e.key}': filterLangsDeep(e.value, langs),
    };
  }
  if (j is List) {
    return <Object?>[for (final v in j) filterLangsDeep(v, langs)];
  }
  return j;
}

/// One lesson file -> what get_lesson_bundle(lesson, langs) returns.
Map<String, dynamic> filterLesson(
  Map<String, dynamic> lesson,
  List<String> langs,
) {
  final unit = lesson['unit'];
  return <String, dynamic>{
    ...lesson,
    if (unit is Map)
      'unit': <String, dynamic>{
        ..._map(unit),
        'title': filterLangs(unit['title'], langs),
      },
    'i18n': filterLangs(_map(lesson['i18n']), langs),
    'cards': <Object?>[
      for (final c
          in lesson['cards'] is List ? lesson['cards'] as List : const [])
        if (c is Map)
          <String, dynamic>{
            ..._map(c),
            'figure': filterLangsDeep(c['figure'], langs),
            'i18n': filterLangs(_map(c['i18n']), langs),
          },
    ],
    'questions': <Object?>[
      for (final q
          in lesson['questions'] is List
              ? lesson['questions'] as List
              : const [])
        if (q is Map)
          <String, dynamic>{
            ..._map(q),
            'figure': filterLangsDeep(q['figure'], langs),
            'option_figures': filterLangsDeep(q['option_figures'], langs),
            'i18n': filterLangs(_map(q['i18n']), langs),
          },
    ],
  };
}

/// The extras file (glossary + sets) -> what get_module_extras returns,
/// WITHOUT "resources" (the library list is not on the CDN).
Map<String, dynamic> filterExtras(
  Map<String, dynamic> extras,
  List<String> langs,
) => <String, dynamic>{
  'glossary': <Object?>[
    for (final g
        in extras['glossary'] is List ? extras['glossary'] as List : const [])
      if (g is Map)
        <String, dynamic>{
          ..._map(g),
          for (final l in const ['fr', 'ar', 'en'])
            if (!langs.contains(l)) l: null,
          'definition': filterLangs(g['definition'], langs),
        },
  ],
  'sets': extras['sets'] is List ? extras['sets'] : const <Object?>[],
};

const _practiceFields = ['title', 'statement', 'figure', 'table', 'parts'];

/// One practice chapter file -> what get_practice returns.
List<Object?> filterPractice(Object? items, List<String> langs) => <Object?>[
  for (final x in items is List ? items : const [])
    if (x is Map)
      <String, dynamic>{
        ..._map(x),
        for (final f in _practiceFields) f: filterLangsDeep(x[f], langs),
      }
    else
      x,
];

/// One exam file -> what get_exam_paper returns.
Map<String, dynamic> filterExam(Map<String, dynamic> x, List<String> langs) =>
    <String, dynamic>{
      ...x,
      for (final f in const ['title', 'instructions', 'exercises'])
        f: filterLangsDeep(x[f], langs),
    };
