import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The per-op answers of sync_progress ({op_id, status, message, coins}),
/// published as they arrive so screens can react (coins earned, story
/// answers). Nothing here decides anything: the server already did.
class SyncResultsBus {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get results => _controller.stream;

  void publish(List<dynamic> results) {
    for (final r in results) {
      if (r is Map && !_controller.isClosed) {
        _controller.add(r.cast<String, dynamic>());
      }
    }
  }

  /// The answer for one op, or null when it does not arrive in time
  /// (offline: the op stays in the outbox and syncs later).
  Future<Map<String, dynamic>?> waitFor(
    String opId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await results
          .firstWhere((r) => r['op_id']?.toString() == opId)
          .timeout(timeout);
    } on TimeoutException {
      return null;
    } on StateError {
      return null;
    }
  }

  void dispose() => _controller.close();
}

final syncResultsProvider = Provider<SyncResultsBus>((ref) {
  final bus = SyncResultsBus();
  ref.onDispose(bus.dispose);
  return bus;
});
