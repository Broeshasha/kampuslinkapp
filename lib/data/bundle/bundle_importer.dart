import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The bundle format this app understands (BACKEND_CONTRACT B).
const supportedBundleSchema = 2;

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
}
