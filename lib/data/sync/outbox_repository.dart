import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/logger.dart';
import '../db/app_database.dart';

const _backoff = [
  Duration(seconds: 5),
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

/// MASTER_PLAN 7.5: 5 s, 30 s, 2 min, 10 min, then every 15 min.
Duration outboxBackoff(int attempts) {
  if (attempts <= 0) return Duration.zero;
  if (attempts <= _backoff.length) return _backoff[attempts - 1];
  return const Duration(minutes: 15);
}

/// The phone-side queue of writes. An op is only deleted when the server
/// answered applied / duplicate / rejected. Network errors keep it.
class OutboxRepository {
  OutboxRepository(this._db, {DateTime Function()? now, Uuid? uuid})
    : _now = now ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;
  int _lastSeq = 0;

  int _nextSeq() {
    final t = _now().microsecondsSinceEpoch;
    _lastSeq = t > _lastSeq ? t : _lastSeq + 1;
    return _lastSeq;
  }

  /// [replaceKey]: keep only the newest op with this key (reading_position).
  Future<String> enqueue(
    String kind,
    Map<String, Object?> payload, {
    String? replaceKey,
  }) async {
    final opId = _uuid.v4();
    final now = _now();
    if (replaceKey != null) {
      await (_db.delete(
        _db.outbox,
      )..where((t) => t.replaceKey.equals(replaceKey))).go();
    }
    await _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion(
            opId: Value(opId),
            seq: Value(_nextSeq()),
            kind: Value(kind),
            payloadJson: Value(jsonEncode(payload)),
            replaceKey: Value(replaceKey),
            createdAt: Value(now),
            nextAttemptAt: Value(now),
          ),
        );
    return opId;
  }

  /// Ops ready to send now, oldest first.
  Future<List<OutboxRow>> due({int limit = 200}) {
    final now = _now();
    return (_db.select(_db.outbox)
          ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)])
          ..limit(limit))
        .get();
  }

  Stream<int> watchPendingCount() {
    final count = countAll();
    final query = _db.selectOnly(_db.outbox)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Applies sync_progress results; returns the sent ids with no answer.
  Future<Set<String>> applyResults(
    List<String> sentIds,
    List<dynamic> results,
  ) async {
    final answered = <String>{};
    await _db.transaction(() async {
      for (final r in results) {
        if (r is! Map) continue;
        final id = r['op_id']?.toString();
        final status = r['status']?.toString();
        if (id == null) continue;
        if (status != 'applied' &&
            status != 'duplicate' &&
            status != 'rejected') {
          continue;
        }
        if (status == 'rejected') {
          appLog.warn('outbox op $id rejected: ${r['message']}');
        }
        answered.add(id);
        await (_db.delete(_db.outbox)..where((t) => t.opId.equals(id))).go();
      }
    });
    return sentIds.toSet().difference(answered);
  }

  /// Network/server failure: keep the ops, wait longer before the next try.
  Future<void> markFailed(Iterable<String> opIds, String error) async {
    final now = _now();
    await _db.transaction(() async {
      for (final id in opIds) {
        final row = await (_db.select(
          _db.outbox,
        )..where((t) => t.opId.equals(id))).getSingleOrNull();
        if (row == null) continue;
        final attempts = row.attempts + 1;
        await (_db.update(_db.outbox)..where((t) => t.opId.equals(id))).write(
          OutboxCompanion(
            attempts: Value(attempts),
            nextAttemptAt: Value(now.add(outboxBackoff(attempts))),
            lastError: Value(error),
          ),
        );
      }
    });
  }
}
