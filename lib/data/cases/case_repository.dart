import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../features/cases/case_models.dart';
import '../../features/cases/demo_cases.dart';
import '../db/app_database.dart';
import '../learning/learning_providers.dart';
import '../providers.dart';
import '../sync/outbox_repository.dart';

const _prefix = 'case:';
const _hintKey = 'case_hint_seen';

/// One stored carousel set (from get_module_extras / the bundle), still
/// in every language.
class CaseSource {
  const CaseSource({
    required this.id,
    required this.source,
    this.moduleId,
    this.lessonId,
    this.position = 0,
  });

  final String id;
  final Map<String, Object?> source;
  final int? moduleId;
  final int? lessonId;
  final int position;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Carousel progress: on the phone at once (key_values `case:<id>`) and
/// queued for the server as one 'case_progress' op per set (the newest
/// replaces the older one). Server rows (learn_set_progress) are merged by
/// ServerMerge after a sync.
class CaseRepository {
  CaseRepository(this._db, [this._outbox]);

  final AppDatabase _db;
  final OutboxRepository? _outbox;

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

  Future<void> save(CaseProgress p) => _db.transaction(() async {
    await _db
        .into(_db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion(
            name: Value('$_prefix${p.setId}'),
            value: Value(jsonEncode(p.toJson())),
          ),
        );
    await _outbox?.enqueue('case_progress', {
      'set_id': p.setId,
      'reached': p.reached,
      'guess': p.guess,
      'correct': p.correct,
      'completed': p.finished,
      'at': DateTime.now().toUtc().toIso8601String(),
    }, replaceKey: 'case_progress:${p.setId}');
  });

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

  /// Every stored set, by module then position (+ the demo sets while
  /// kShowDemoCases is on).
  Future<List<CaseSource>> sources() async {
    final rows = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.like('sets:%'))).get();
    final out = <CaseSource>[];
    for (final r in rows) {
      final moduleId = int.tryParse(r.name.substring(5));
      Object? list;
      try {
        list = jsonDecode(r.value);
      } on FormatException {
        continue;
      }
      if (list is! List) continue;
      for (final s in list) {
        if (s is! Map) continue;
        final m = s.cast<String, Object?>();
        final id = '${m['id'] ?? ''}';
        if (id.isEmpty) continue;
        out.add(
          CaseSource(
            id: id,
            source: m,
            moduleId: _int(m['module_id']) ?? moduleId,
            lessonId: _int(m['lesson_id']),
            position: _int(m['position']) ?? out.length,
          ),
        );
      }
    }
    out.sort((a, b) {
      final m = (a.moduleId ?? 0).compareTo(b.moduleId ?? 0);
      return m != 0 ? m : a.position.compareTo(b.position);
    });
    if (kShowDemoCases) {
      for (var i = 0; i < demoCases.length; i++) {
        out.add(
          CaseSource(
            id: '${demoCases[i]['id']}',
            source: demoCases[i],
            position: 1000 + i,
          ),
        );
      }
    }
    return out;
  }

  /// The animated "swipe" hint is shown once per phone.
  Future<bool> hintSeen() async =>
      (await (_db.select(
        _db.keyValues,
      )..where((t) => t.name.equals(_hintKey))).getSingleOrNull()) !=
      null;

  Future<void> markHintSeen() => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        const KeyValuesCompanion(name: Value(_hintKey), value: Value('1')),
      );
}

final caseRepositoryProvider = Provider<CaseRepository>(
  (ref) => CaseRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
  ),
);

final caseProgressProvider = StreamProvider<Map<String, CaseProgress>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const {});
  return ref.watch(caseRepositoryProvider).watchAll();
});

/// Stored sets, reloaded when downloaded content changes.
final caseSourcesProvider = FutureProvider<List<CaseSource>>((ref) {
  ref.watch(downloadedKeyProvider);
  return ref.watch(caseRepositoryProvider).sources();
});

final caseHintSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(caseRepositoryProvider).hintSeen(),
);
