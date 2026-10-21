import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../features/cases/case_models.dart';
import '../db/app_database.dart';
import '../providers.dart';

const _prefix = 'case:';

/// Carousel progress, on the phone only (key_values) until backend file 11
/// defines the server side; then it will also go through the outbox.
class CaseRepository {
  CaseRepository(this._db);

  final AppDatabase _db;

  CaseProgress _decode(String setId, String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map) return CaseProgress.fromJson(v.cast<String, dynamic>());
    } on FormatException {
      // fall through
    }
    return CaseProgress(setId: setId);
  }

  Future<CaseProgress> get(String setId) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals('$_prefix$setId'))).getSingleOrNull();
    return row == null ? CaseProgress(setId: setId) : _decode(setId, row.value);
  }

  Future<void> save(CaseProgress p) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(
          name: Value('$_prefix${p.setId}'),
          value: Value(jsonEncode(p.toJson())),
        ),
      );

  Future<Map<String, CaseProgress>> all() async => _toMap(
    await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.like('$_prefix%'))).get(),
  );

  Stream<Map<String, CaseProgress>> watchAll() => (_db.select(
    _db.keyValues,
  )..where((t) => t.name.like('$_prefix%'))).watch().map(_toMap);

  Map<String, CaseProgress> _toMap(List<KeyValueRow> rows) => {
    for (final r in rows)
      r.name.substring(_prefix.length): _decode(
        r.name.substring(_prefix.length),
        r.value,
      ),
  };
}

final caseRepositoryProvider = Provider<CaseRepository>(
  (ref) => CaseRepository(ref.watch(appDatabaseProvider)),
);

final caseProgressProvider = StreamProvider<Map<String, CaseProgress>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const {});
  return ref.watch(caseRepositoryProvider).watchAll();
});
