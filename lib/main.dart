import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/errors/error_handlers.dart';
import 'core/l10n/locale_controller.dart';
import 'core/logging/logger.dart';
import 'core/theme/font_licenses.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers();
    registerFontLicenses();
    final prefs = await SharedPreferences.getInstance();
    runApp(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const KampusLinkApp(),
      ),
    );
  }, (error, stack) => appLog.error(error, stack, fatal: true, reason: 'zone'));
}
