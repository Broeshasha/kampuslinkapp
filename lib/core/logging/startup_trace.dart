import 'package:flutter/foundation.dart';

/// Start-up timing, printed in debug and profile runs only (`flutter run`):
///   STARTUP   412 ms (+180)  first frame
/// Each step is printed once. Never shipped in release builds.
class StartupTrace {
  final Stopwatch _watch = Stopwatch()..start();
  final Set<String> _done = {};
  int _last = 0;

  void mark(String step, [String detail = '']) {
    if (kReleaseMode || !_done.add(step)) {
      return;
    }
    final now = _watch.elapsedMilliseconds;
    final extra = detail.isEmpty ? '' : ' ($detail)';
    debugPrint(
      'STARTUP ${now.toString().padLeft(5)} ms '
      '(+${now - _last})  $step$extra',
    );
    _last = now;
  }
}

/// Starts counting at the first mark in main().
final startupTrace = StartupTrace();
