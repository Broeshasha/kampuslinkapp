import 'package:flutter/foundation.dart';

/// Where errors go beyond the phone (Crashlytics is plugged in later).
abstract interface class CrashSink {
  void record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? reason,
  });
  void log(String message);
}

/// One logger for the whole app. Keeps the last 200 lines in memory
/// (useful for "report a problem") and forwards to the crash sink.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();
  static const _keep = 200;

  CrashSink? sink;
  final _recent = <String>[];

  List<String> get recent => List.unmodifiable(_recent);

  void info(String message) => _write('I', message, forward: true);

  void warn(String message) => _write('W', message, forward: true);

  void error(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) {
    _write(fatal ? 'F' : 'E', '${reason ?? 'error'}: $error', forward: false);
    try {
      sink?.record(error, stack, fatal: fatal, reason: reason);
    } catch (_) {
      // Logging must never crash the app.
    }
  }

  void _write(String level, String message, {required bool forward}) {
    final line = '${DateTime.now().toIso8601String()} $level $message';
    _recent.add(line);
    if (_recent.length > _keep) _recent.removeAt(0);
    if (kDebugMode) debugPrint(line);
    if (!forward) return;
    try {
      sink?.log(line);
    } catch (_) {
      // Logging must never crash the app.
    }
  }
}

final appLog = AppLogger.instance;
