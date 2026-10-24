import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/errors/result.dart';
import '../../core/logging/logger.dart';
import '../db/app_database.dart';
import '../sync/outbox_repository.dart';
import 'assess_models.dart';

/// Practice + mock exams on the phone (contract file 15), in key_values
/// (no schema change): indexes from the manifest, downloaded chapters and
/// papers with their rev, practice progress and exam attempts.
class AssessStore {
  AssessStore(this._db, this._outbox, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final DateTime Function() _now;

  Future<Object?> _get(String key) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.name.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _put(String key, Object? value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(jsonEncode(value))),
      );

  Future<void> _delete(String key) =>
      (_db.delete(_db.keyValues)..where((t) => t.name.equals(key))).go();

  List<Map<String, dynamic>> _maps(Object? v) => [
    if (v is List)
      for (final e in v)
        if (e is Map) e.cast<String, dynamic>(),
  ];

  // ---- indexes (from the manifest) ----

  Future<List<Map<String, dynamic>>> practiceIndex(int moduleId) async =>
      _maps(await _get('practice_index:$moduleId'));

  Future<List<Map<String, dynamic>>> examIndex(int moduleId) async =>
      _maps(await _get('exams:$moduleId'));

  // ---- downloaded content ----

  Future<List<Map<String, dynamic>>> practiceChapter(
    int moduleId,
    String chapterRef,
  ) async => _maps(await _get('practice:$moduleId:$chapterRef'));

  Future<Map<String, dynamic>?> examPaper(int paperId) async {
    final v = await _get('exam:$paperId');
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  Future<String?> _rev(String key) async {
    final v = await _get(key);
    return v is String ? v : null;
  }

  /// Applies one manifest: downloads what is new or changed (rev), deletes
  /// what disappeared. [fetchPractice] / [fetchPaper] are the server calls.
  Future<void> applyManifest(
    int moduleId,
    Map<String, dynamic> manifest, {
    required Future<List<Object?>> Function(String chapterRef) fetchPractice,
    required Future<Map<String, dynamic>> Function(int paperId) fetchPaper,
  }) async {
    final practice = _maps(manifest['practice']);
    final exams = _maps(manifest['exams']);
    final oldPractice = await practiceIndex(moduleId);
    final oldExams = await examIndex(moduleId);
    for (final p in practice) {
      final ref = '${p['chapter_ref'] ?? ''}';
      if (ref.isEmpty) continue;
      final rev = '${p['rev'] ?? ''}';
      final revKey = 'practice_rev:$moduleId:$ref';
      if (await _rev(revKey) == rev &&
          await _get('practice:$moduleId:$ref') != null) {
        continue;
      }
      final r = await guard(() => fetchPractice(ref));
      if (r case Ok(:final value)) {
        await _put('practice:$moduleId:$ref', value);
        await _put(revKey, rev);
      } else if (r case Err(:final failure)) {
        appLog.warn('practice $moduleId/$ref not downloaded: $failure');
      }
    }
    final keepChapters = {for (final p in practice) '${p['chapter_ref']}'};
    for (final p in oldPractice) {
      final ref = '${p['chapter_ref']}';
      if (!keepChapters.contains(ref)) {
        await _delete('practice:$moduleId:$ref');
        await _delete('practice_rev:$moduleId:$ref');
      }
    }
    for (final e in exams) {
      final id = e['id'];
      if (id is! num) continue;
      final rev = '${e['rev'] ?? ''}';
      final revKey = 'exam_rev:${id.toInt()}';
      if (await _rev(revKey) == rev &&
          await _get('exam:${id.toInt()}') != null) {
        continue;
      }
      final r = await guard(() => fetchPaper(id.toInt()));
      if (r case Ok(:final value)) {
        await _put('exam:${id.toInt()}', value);
        await _put(revKey, rev);
      } else if (r case Err(:final failure)) {
        appLog.warn('exam $id not downloaded: $failure');
      }
    }
    final keepPapers = {for (final e in exams) '${e['id']}'};
    for (final e in oldExams) {
      if (!keepPapers.contains('${e['id']}')) {
        await _delete('exam:${e['id']}');
        await _delete('exam_rev:${e['id']}');
      }
    }
    await _put('practice_index:$moduleId', practice);
    await _put('exams:$moduleId', exams);
  }

  // ---- practice progress ----

  Future<Map<String, dynamic>> practiceProgress(int practiceId) async {
    final v = await _get('practice_prog:$practiceId');
    return v is Map ? v.cast<String, dynamic>() : const {};
  }

  /// Same rule as the server: max hints, solution_seen sticky, latest
  /// rating. One op per item (an unsent one is replaced).
  Future<void> savePracticeProgress(
    int practiceId, {
    int hintsSeen = 0,
    bool solutionSeen = false,
    String? rating,
  }) async {
    final old = await practiceProgress(practiceId);
    final oldHints = old['hints_seen'];
    final merged = <String, Object?>{
      'practice_id': practiceId,
      'hints_seen': oldHints is num && oldHints > hintsSeen
          ? oldHints.toInt()
          : hintsSeen,
      'solution_seen': solutionSeen || old['solution_seen'] == true,
      'self_rating': rating ?? old['self_rating'],
      'at': _now().toUtc().toIso8601String(),
    };
    await _put('practice_prog:$practiceId', merged);
    await _outbox.enqueue(
      'practice_progress',
      merged,
      replaceKey: 'practice_progress:$practiceId',
    );
  }

  // ---- exam attempts ----

  Future<List<ExamAttempt>> attempts(int paperId) async => [
    for (final m in _maps(await _get('exam_attempts:$paperId')))
      ExamAttempt.fromMap(m),
  ];

  Future<void> _storeAttempts(int paperId, List<ExamAttempt> list) =>
      _put('exam_attempts:$paperId', [for (final a in list) a.toPayload()]);

  ExamAttempt _merge(ExamAttempt? old, ExamAttempt incoming) {
    if (old == null) return incoming;
    // Same instant = the incoming edit (the phone can save twice in 1 ms).
    final newer = incoming.at.isBefore(old.at) ? old : incoming;
    // "finished" never goes back.
    if (old.status == AttemptStatus.finished &&
        newer.status != AttemptStatus.finished) {
      return newer.copyWith(
        status: AttemptStatus.finished,
        finishedAt: old.finishedAt,
      );
    }
    return newer;
  }

  /// Saves an attempt on the phone and queues the WHOLE attempt for the
  /// server (start, finish, every correction save).
  Future<void> saveAttempt(ExamAttempt attempt) async {
    final list = await attempts(attempt.paperId);
    final i = list.indexWhere((a) => a.attemptId == attempt.attemptId);
    final merged = _merge(i < 0 ? null : list[i], attempt);
    if (i < 0) {
      list.add(merged);
    } else {
      list[i] = merged;
    }
    await _storeAttempts(attempt.paperId, list);
    await _outbox.enqueue(
      'exam_attempt',
      merged.toPayload(),
      replaceKey: 'exam_attempt:${attempt.attemptId}',
    );
  }

  /// get_my_exam_attempts rows (new phone / reinstall): merged, no op sent.
  Future<void> mergeServerAttempts(List<Map<String, dynamic>> rows) async {
    final byPaper = <int, List<ExamAttempt>>{};
    for (final r in rows) {
      final a = ExamAttempt.fromMap(r);
      if (a.attemptId.isEmpty) continue;
      byPaper.putIfAbsent(a.paperId, () => []).add(a);
    }
    for (final e in byPaper.entries) {
      final list = await attempts(e.key);
      for (final a in e.value) {
        final i = list.indexWhere((x) => x.attemptId == a.attemptId);
        if (i < 0) {
          list.add(a);
        } else {
          list[i] = _merge(list[i], a);
        }
      }
      await _storeAttempts(e.key, list);
    }
  }
}

/// Best score /20 of the finished attempts (null = none yet).
double? bestScore20(List<ExamAttempt> attempts, ExamPaper paper) {
  double? best;
  final max = paper.maxByKey;
  for (final a in attempts) {
    if (a.status != AttemptStatus.finished) continue;
    final s = score20(attemptTotal(a.scores, max), paper.totalPoints);
    if (best == null || s > best) best = s;
  }
  return best;
}

/// The attempt still running for this paper, if any (newest first).
ExamAttempt? openAttempt(List<ExamAttempt> attempts) {
  ExamAttempt? out;
  for (final a in attempts) {
    if (a.status != AttemptStatus.inProgress) continue;
    if (out == null || a.startedAt.isAfter(out.startedAt)) out = a;
  }
  return out;
}

/// The newest finished attempt (to reopen its correction).
ExamAttempt? lastFinished(List<ExamAttempt> attempts) {
  ExamAttempt? out;
  for (final a in attempts) {
    if (a.status != AttemptStatus.finished) continue;
    if (out == null || a.startedAt.isAfter(out.startedAt)) out = a;
  }
  return out;
}
