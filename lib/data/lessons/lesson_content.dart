import 'dart:convert';

import '../db/app_database.dart';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

Map<String, dynamic> _decode(String? json) {
  if (json == null || json.isEmpty) return const <String, dynamic>{};
  try {
    return _map(jsonDecode(json));
  } on FormatException {
    return const <String, dynamic>{};
  }
}

/// Best available language: wanted -> French -> source language -> any.
String pickLanguage(
  Iterable<String> available,
  String wanted, {
  String? source,
}) {
  final list = available.toList();
  if (list.isEmpty) return wanted;
  for (final code in [wanted, 'fr', ?source]) {
    if (list.contains(code)) return code;
  }
  return list.first;
}

/// One stored lesson, decoded for the screen in one language.
/// [languages] = the languages that really have content.
class LessonContent {
  LessonContent._(
    this.row,
    this.language,
    this.languages,
    this._data,
    this._unit,
  );

  /// Language order: [wanted] -> French -> source -> any other; a language
  /// whose blocks are empty is skipped, so a lesson is never shown empty.
  factory LessonContent.of(LessonRow row, String wanted) {
    final i18n = _decode(row.i18nJson);
    bool readable(String lang) {
      final blocks = _map(i18n[lang])['blocks'];
      return blocks is List && blocks.isNotEmpty;
    }

    final all = i18n.keys.toList();
    final withBlocks = all.where(readable).toList();
    final languages = withBlocks.isEmpty ? all : withBlocks;
    final language = pickLanguage(languages, wanted, source: row.sourceLang);
    return LessonContent._(
      row,
      language,
      languages,
      _map(i18n[language]),
      _decode(row.unitJson),
    );
  }

  final LessonRow row;
  final String language;
  final List<String> languages;
  final Map<String, dynamic> _data;
  final Map<String, dynamic> _unit;

  int get id => row.id;
  String get title => '${_data['title'] ?? ''}';
  String get summary => '${_data['summary'] ?? ''}';

  List<Map<String, dynamic>> get blocks {
    final raw = _data['blocks'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final b in raw)
        if (b is Map) b.cast<String, dynamic>(),
    ];
  }

  int? get unitNumber {
    final n = _unit['number'];
    return n is num ? n.toInt() : null;
  }

  /// Groups lessons of the same unit together in the module page.
  String get unitKey => '${_unit['ref'] ?? _unit['number'] ?? ''}';

  String get unitTitle {
    final t = _unit['title'];
    if (t is Map) {
      final m = t.cast<String, dynamic>();
      return '${m[pickLanguage(m.keys, language)] ?? ''}';
    }
    return t == null ? '' : '$t';
  }
}
