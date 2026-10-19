import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/logger.dart';

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// true = the phone has a network. If the check itself fails we assume
/// online (no false "offline" banner) and log it: never silent.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  try {
    yield _isOnline(await connectivity.checkConnectivity());
  } catch (error, stack) {
    appLog.error(error, stack, reason: 'connectivity check');
    yield true;
  }
  yield* connectivity.onConnectivityChanged
      .map(_isOnline)
      .handleError(
        (Object error, StackTrace stack) =>
            appLog.error(error, stack, reason: 'connectivity stream'),
      );
});

/// Simple bool for widgets: online unless we KNOW we are offline.
final isOnlineProvider = Provider<bool>(
  (ref) => switch (ref.watch(connectivityProvider)) {
    AsyncData(:final value) => value,
    _ => true,
  },
);
