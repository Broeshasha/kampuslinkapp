import 'dart:convert';

import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/logging/logger.dart';
import 'outbox_repository.dart';

/// Sends a batch to the server (sync_progress) and returns its results.
typedef SendOps = Future<List<dynamic>> Function(
  List<Map<String, Object?>> ops,
);

class FlushResult {
  const FlushResult({this.sent = 0, this.failure});
  final int sent;
  final AppFailure? failure;
  bool get ok => failure == null;
}

/// Drains the outbox in batches of 200, oldest first. One flush at a time.
class OutboxSync {
  OutboxSync(this._outbox, this._send);

  final OutboxRepository _outbox;
  final SendOps _send;
  Future<FlushResult>? _running;

  Future<FlushResult> flush() =>
      _running ??= _flush().whenComplete(() => _running = null);

  Future<FlushResult> _flush() async {
    var sent = 0;
    for (var round = 0; round < 50; round++) {
      final batch = await _outbox.due(limit: 200);
      if (batch.isEmpty) break;
      final ids = [for (final r in batch) r.opId];
      final ops = [
        for (final r in batch)
          <String, Object?>{
            'op_id': r.opId,
            'kind': r.kind,
            'payload': jsonDecode(r.payloadJson),
          },
      ];
      final List<dynamic> results;
      try {
        results = await _send(ops);
      } catch (error, stack) {
        final failure = mapError(error);
        if (failure is OfflineFailure) {
          appLog.info('outbox: offline, ${ids.length} ops kept');
        } else {
          appLog.error(error, stack, reason: 'outbox flush');
        }
        await _outbox.markFailed(ids, failure.toString());
        return FlushResult(sent: sent, failure: failure);
      }
      final unanswered = await _outbox.applyResults(ids, results);
      if (unanswered.isNotEmpty) {
        appLog.warn('outbox: ${unanswered.length} ops without a result');
        await _outbox.markFailed(unanswered, 'no_result');
      }
      sent += ids.length - unanswered.length;
    }
    return FlushResult(sent: sent);
  }
}
