import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The bundle format this app understands (BACKEND_CONTRACT B; 3 = file 13:
/// tags and sets added, read when present).
const supportedBundleSchema = 3;

class UnsupportedBundleSchema implements Exception {
  const UnsupportedBundleSchema(this.version);
  final int version;

  @override
  String toString() => 'UnsupportedBundleSchema($version)';
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
String? _str(Object? v) => v?.toString();

/// Stores one get_module_bundle() result. The module's old content is
/// replaced in ONE transaction: never half old / half new.
class BundleImporter {
  BundleImporter(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<void> importBundle(Map<String, dynamic> bundle) async {
    final schema = _int(bundle['schema_version']);
    if (schema > supportedBundleSchema) throw UnsupportedBundleSchema(schema);
    final module = _map(bundle['module']);
    final moduleId = _int(module['id']);
    final version = _int(bundle['version']);
    final languages = _list(bundle['languages']).map((e) => '$e').join(',');
    final lessons = _list(bundle['lessons']).map(_map).toList();
    final resources = _list(bundle['resources']).map(_map).toList();
    final glossary = _list(bundle['glossary']).map(_map).toList();

    await _db.transaction(() async {
      await (_db.delete(
        _db.cards,
      )..where((t) => t.moduleId.equals(moduleId))).go();
      await (_db.delete(
        _db.questions,
      )..where((t) => t.moduleId.equals(moduleId))).go();
      await (_db.delete(
        _db.lessons,
      )..where((t) => t.moduleId.equals(moduleId))).go();
      await (_db.delete(
        _db.resources,
      )..where((t) => t.moduleId.equals(moduleId))).go();
      await (_db.delete(
        _db.glossaryEntries,
      )..where((t) => t.moduleId.equals(moduleId))).go();

      await _db.batch((b) {
        for (final l in lessons) {
          final lessonId = _int(l['id']);
          b.insert(
            _db.lessons,
            LessonsCompanion(
              id: Value(lessonId),
              moduleId: Value(moduleId),
              position: Value(_int(l['position'])),
              sourceLang: Value(_str(l['source_lang'])),
              unitJson: Value(l['unit'] == null ? null : jsonEncode(l['unit'])),
              estimatedMinutes: Value(_intOrNull(l['estimated_minutes'])),
              i18nJson: Value(jsonEncode(l['i18n'] ?? const {})),
              resourceLinksJson: Value(jsonEncode(l['resources'] ?? const [])),
            ),
            mode: InsertMode.insertOrReplace,
          );
          for (final c in _list(l['cards']).map(_map)) {
            b.insert(
              _db.cards,
              CardsCompanion(
                id: Value(_int(c['id'])),
                lessonId: Value(lessonId),
                moduleId: Value(moduleId),
                position: Value(_int(c['position'])),
                i18nJson: Value(jsonEncode(c['i18n'] ?? const {})),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
          for (final q in _list(l['questions']).map(_map)) {
            b.insert(
              _db.questions,
              QuestionsCompanion(
                id: Value(_int(q['id'])),
                lessonId: Value(lessonId),
                moduleId: Value(moduleId),
                kind: Value(_str(q['kind']) ?? 'mcq'),
                correctIndex: Value(_int(q['correct_index'])),
                position: Value(_int(q['position'])),
                i18nJson: Value(jsonEncode(q['i18n'] ?? const {})),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
        for (final r in resources) {
          b.insert(
            _db.resources,
            ResourcesCompanion(
              id: Value(_int(r['id'])),
              moduleId: Value(moduleId),
              type: Value(_str(r['type']) ?? 'other'),
              format: Value(_str(r['format'])),
              title: Value(_str(r['title']) ?? ''),
              fileUrlsJson: Value(jsonEncode(r['file_urls'] ?? const [])),
              trustLabel: Value(_str(r['trust_label'])),
              sizeBytes: Value(_intOrNull(r['size_bytes'])),
              origin: Value(_str(r['origin'])),
              createdAt: Value(DateTime.tryParse('${r['created_at']}')),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final g in glossary) {
          b.insert(
            _db.glossaryEntries,
            GlossaryEntriesCompanion(
              id: Value(_int(g['id'])),
              moduleId: Value(moduleId),
              fr: Value(_str(g['fr'])),
              ar: Value(_str(g['ar'])),
              en: Value(_str(g['en'])),
              definitionJson: Value(jsonEncode(g['definition'] ?? const {})),
              note: Value(_str(g['note'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      await _saveSets(moduleId, bundle['sets']);
      for (final l in lessons) {
        await _saveMeta(l);
      }
      await _db
          .into(_db.modules)
          .insertOnConflictUpdate(
            ModulesCompanion(
              id: Value(moduleId),
              name: Value(_str(module['name']) ?? ''),
              semester: Value(_intOrNull(module['semester'])),
              ueCategory: Value(_str(module['ue_category'])),
              academicYear: Value(_str(module['academic_year'])),
              serverVersion: Value(version),
              localVersion: Value(version),
              lessonCount: Value(lessons.length),
              resourceCount: Value(resources.length),
              languages: Value(languages),
              downloadedAt: Value(_now()),
            ),
          );
    });
  }

  Map<String, dynamic> _decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final v = jsonDecode(json);
      return v is Map ? v.cast<String, dynamic>() : {};
    } on FormatException {
      return {};
    }
  }

  /// Carousel sets (file 13) wait in key_values until the feed reads them.
  Future<void> _saveSets(int moduleId, Object? sets) async {
    if (sets is! List) return;
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion(
            name: Value('sets:$moduleId'),
            value: Value(jsonEncode(sets)),
          ),
        );
  }

  /// File 13 fields the feed uses (cards: concept, difficulty, card_kind;
  /// questions: concept, difficulty), kept in key_values `meta:<lesson>`
  /// so no schema change is needed. Null fields are simply left out.
  Future<void> _saveMeta(
    Map<String, dynamic> lesson, {
    bool merge = false,
  }) async {
    final key = 'meta:${_int(lesson['id'])}';
    Map<String, dynamic> fields(Map<String, dynamic> m, List<String> keys) => {
      for (final k in keys)
        if (m[k] != null) k: m[k],
    };
    final cards = <String, dynamic>{
      for (final c in _list(lesson['cards']).map(_map))
        '${_int(c['id'])}': fields(c, const [
          'concept',
          'difficulty',
          'card_kind',
        ]),
    }..removeWhere((_, v) => (v as Map).isEmpty);
    final questions = <String, dynamic>{
      for (final q in _list(lesson['questions']).map(_map))
        '${_int(q['id'])}': fields(q, const ['concept', 'difficulty']),
    }..removeWhere((_, v) => (v as Map).isEmpty);
    if (merge) {
      if (cards.isEmpty && questions.isEmpty) return;
      final row = await (_db.select(
        _db.keyValues,
      )..where((t) => t.name.equals(key))).getSingleOrNull();
      final old = _decodeMap(row?.value);
      cards.addAll({..._map(old['c']), ...cards});
      questions.addAll({..._map(old['q']), ...questions});
    }
    if (cards.isEmpty && questions.isEmpty) {
      await (_db.delete(_db.keyValues)..where((t) => t.name.equals(key))).go();
      return;
    }
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion(
            name: Value(key),
            value: Value(jsonEncode({'c': cards, 'q': questions})),
          ),
        );
  }

  /// One lesson from get_lesson_bundle, in its OWN transaction.
  /// [merge] = add the languages in [lesson] to what is stored (top-up);
  /// otherwise the lesson's cards and questions are replaced.
  Future<void> importLesson(
    int moduleId,
    Map<String, dynamic> lesson, {
    bool merge = false,
  }) => _db.transaction(() async {
    final lessonId = _int(lesson['id']);
    final existing = await (_db.select(
      _db.lessons,
    )..where((t) => t.id.equals(lessonId))).getSingleOrNull();
    final i18n = {
      if (merge && existing != null) ..._decodeMap(existing.i18nJson),
      ..._map(lesson['i18n']),
    };
    if (!merge) {
      await (_db.delete(
        _db.cards,
      )..where((t) => t.lessonId.equals(lessonId))).go();
      await (_db.delete(
        _db.questions,
      )..where((t) => t.lessonId.equals(lessonId))).go();
    }
    await _db
        .into(_db.lessons)
        .insertOnConflictUpdate(
          LessonsCompanion(
            id: Value(lessonId),
            moduleId: Value(moduleId),
            position: Value(
              merge && existing != null && lesson['position'] == null
                  ? existing.position
                  : _int(lesson['position']),
            ),
            sourceLang: Value(
              _str(lesson['source_lang']) ?? existing?.sourceLang,
            ),
            unitJson: Value(
              lesson['unit'] == null
                  ? existing?.unitJson
                  : jsonEncode(lesson['unit']),
            ),
            estimatedMinutes: Value(
              _intOrNull(lesson['estimated_minutes']) ??
                  existing?.estimatedMinutes,
            ),
            i18nJson: Value(jsonEncode(i18n)),
            resourceLinksJson: Value(
              lesson['resources'] == null
                  ? (existing?.resourceLinksJson ?? '[]')
                  : jsonEncode(lesson['resources']),
            ),
          ),
        );
    for (final c in _list(lesson['cards']).map(_map)) {
      final id = _int(c['id']);
      final old = merge
          ? await (_db.select(
              _db.cards,
            )..where((t) => t.id.equals(id))).getSingleOrNull()
          : null;
      await _db
          .into(_db.cards)
          .insertOnConflictUpdate(
            CardsCompanion(
              id: Value(id),
              lessonId: Value(lessonId),
              moduleId: Value(moduleId),
              position: Value(_int(c['position'] ?? old?.position)),
              i18nJson: Value(
                jsonEncode({
                  if (old != null) ..._decodeMap(old.i18nJson),
                  ..._map(c['i18n']),
                }),
              ),
            ),
          );
    }
    for (final q in _list(lesson['questions']).map(_map)) {
      final id = _int(q['id']);
      final old = merge
          ? await (_db.select(
              _db.questions,
            )..where((t) => t.id.equals(id))).getSingleOrNull()
          : null;
      await _db
          .into(_db.questions)
          .insertOnConflictUpdate(
            QuestionsCompanion(
              id: Value(id),
              lessonId: Value(lessonId),
              moduleId: Value(moduleId),
              kind: Value(_str(q['kind']) ?? old?.kind ?? 'mcq'),
              correctIndex: Value(
                _int(q['correct_index'] ?? old?.correctIndex),
              ),
              position: Value(_int(q['position'] ?? old?.position)),
              i18nJson: Value(
                jsonEncode({
                  if (old != null) ..._decodeMap(old.i18nJson),
                  ..._map(q['i18n']),
                }),
              ),
            ),
          );
    }
    await _saveMeta(lesson, merge: merge);
  });

  /// get_module_extras: glossary and resources replaced, sets kept for the feed.
  Future<void> importExtras(int moduleId, Map<String, dynamic> extras) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.glossaryEntries,
        )..where((t) => t.moduleId.equals(moduleId))).go();
        await (_db.delete(
          _db.resources,
        )..where((t) => t.moduleId.equals(moduleId))).go();
        for (final g in _list(extras['glossary']).map(_map)) {
          await _db
              .into(_db.glossaryEntries)
              .insertOnConflictUpdate(
                GlossaryEntriesCompanion(
                  id: Value(_int(g['id'])),
                  moduleId: Value(moduleId),
                  fr: Value(_str(g['fr'])),
                  ar: Value(_str(g['ar'])),
                  en: Value(_str(g['en'])),
                  definitionJson: Value(
                    jsonEncode(g['definition'] ?? const {}),
                  ),
                  note: Value(_str(g['note'])),
                ),
              );
        }
        for (final r in _list(extras['resources']).map(_map)) {
          await _db
              .into(_db.resources)
              .insertOnConflictUpdate(
                ResourcesCompanion(
                  id: Value(_int(r['id'])),
                  moduleId: Value(moduleId),
                  type: Value(_str(r['type']) ?? 'other'),
                  format: Value(_str(r['format'])),
                  title: Value(_str(r['title']) ?? ''),
                  fileUrlsJson: Value(jsonEncode(r['file_urls'] ?? const [])),
                  trustLabel: Value(_str(r['trust_label'])),
                  sizeBytes: Value(_intOrNull(r['size_bytes'])),
                  origin: Value(_str(r['origin'])),
                  createdAt: Value(DateTime.tryParse('${r['created_at']}')),
                ),
              );
        }
        await _saveSets(moduleId, extras['sets']);
      });

  /// Lessons that left the manifest disappear with their cards and questions.
  Future<void> deleteLessons(Iterable<int> lessonIds) =>
      _db.transaction(() async {
        final ids = lessonIds.toList();
        if (ids.isEmpty) return;
        await (_db.delete(_db.cards)..where((t) => t.lessonId.isIn(ids))).go();
        await (_db.delete(
          _db.questions,
        )..where((t) => t.lessonId.isIn(ids))).go();
        await (_db.delete(_db.lessons)..where((t) => t.id.isIn(ids))).go();
        await (_db.delete(
          _db.keyValues,
        )..where((t) => t.name.isIn([for (final id in ids) 'meta:$id']))).go();
      });
}
