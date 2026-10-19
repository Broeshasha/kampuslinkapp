import 'package:flutter/widgets.dart';

import '../../ui/friendly_error.dart';
import '../logging/logger.dart';

/// Global safety net: framework errors, async errors outside Flutter,
/// and widget build crashes (friendly box instead of the red screen).
void installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    appLog.error(
      details.exception,
      details.stack,
      reason: 'flutter: ${details.context?.toDescription() ?? 'unknown'}',
    );
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    appLog.error(error, stack, fatal: true, reason: 'platform');
    return true;
  };
  ErrorWidget.builder = (details) => FriendlyBuildError(details: details);
}
