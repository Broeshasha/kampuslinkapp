import 'package:drift/drift.dart';

import '../db/app_database.dart';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);

/// Local module list. The UI only ever reads from here (MASTER_PLAN 7.1).
class ModuleRepository {
  ModuleRepository(this._db);

  final AppDatabase _db;

  Stream<List<ModuleRow>> watchModules() =>
      (_db.select(_db.modules)..orderBy([
            (t) => OrderingTerm.asc(t.semester),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .watch();

  /// Saves get_my_modules() rows. Keeps what was downloaded (localVersion);
  /// removes modules that are no longer the student's (and their content).
  Future<void> saveServerList(List<Map<String, dynamic>> rows) async {
    final ids = <int>{};
    await _db.transaction(() async {
      for (final r in rows) {
        final id = _int(r['module_id']);
        ids.add(id);
        await _db
            .into(_db.modules)
            .insertOnConflictUpdate(
              ModulesCompanion(
                id: Value(id),
                name: Value('${r['name'] ?? ''}'),
                semester: Value(_intOrNull(r['semester'])),
                ueCategory: Value(r['ue_category']?.toString()),
                academicYear: Value(r['academic_year']?.toString()),
                serverVersion: Value(_int(r['version'])),
                lessonCount: Value(_int(r['lessons'])),
                lessonsDone: Value(_int(r['lessons_done'])),
                resourceCount: Value(_int(r['resources'])),
              ),
            );
      }
      final stale = await (_db.select(
        _db.modules,
      )..where((t) => t.id.isNotIn(ids))).get();
      for (final m in stale) {
        await _deleteModule(m.id);
      }
    });
  }

  /// Modules with content that are not complete on the phone: newer on
  /// the server, interrupted (resumable), or missing one of [langs].
  Future<List<ModuleRow>> needingDownload({
    List<String> langs = const [],
  }) async {
    final rows = await (_db.select(
      _db.modules,
    )..where((t) => t.serverVersion.isBiggerThanValue(0))).get();
    return [
      for (final m in rows)
        if (m.serverVersion > m.localVersion || !_covers(m.languages, langs)) m,
    ];
  }

  bool _covers(String stored, List<String> langs) {
    final have = stored.split(',').where((s) => s.isNotEmpty).toSet();
    return langs.every(have.contains);
  }

  Future<void> _deleteModule(int id) async {
    await (_db.delete(_db.cards)..where((t) => t.moduleId.equals(id))).go();
    await (_db.delete(_db.questions)..where((t) => t.moduleId.equals(id))).go();
    await (_db.delete(_db.lessons)..where((t) => t.moduleId.equals(id))).go();
    await (_db.delete(_db.resources)..where((t) => t.moduleId.equals(id))).go();
    await (_db.delete(
      _db.glossaryEntries,
    )..where((t) => t.moduleId.equals(id))).go();
    await (_db.delete(_db.modules)..where((t) => t.id.equals(id))).go();
  }
}
