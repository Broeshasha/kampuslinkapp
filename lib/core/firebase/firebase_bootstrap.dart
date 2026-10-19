import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../logging/logger.dart';

/// Sends our logger's errors to Firebase Crashlytics.
class CrashlyticsSink implements CrashSink {
  CrashlyticsSink(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? reason,
  }) => _crashlytics.recordError(error, stack, fatal: fatal, reason: reason);

  @override
  void log(String message) => _crashlytics.log(message);
}

/// Starts Firebase (Android uses google-services.json) and plugs
/// Crashlytics into the logger. Never blocks start-up for long and never
/// throws: a failure is logged and the app continues without it.
Future<void> initFirebase() async {
  if (kIsWeb) {
    appLog.info('firebase: skipped on web (Crashlytics is mobile only)');
    return;
  }
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    await crashlytics.setCustomKey('build', kDebugMode ? 'debug' : 'release');
    appLog.sink = CrashlyticsSink(crashlytics);
    appLog.info('firebase: ready, crashlytics on');
  } catch (error, stack) {
    appLog.error(error, stack, reason: 'firebase init');
  }
}
