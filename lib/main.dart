import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/errors/error_handlers.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/l10n/locale_controller.dart';
import 'core/logging/logger.dart';
import 'core/logging/startup_trace.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/font_licenses.dart';
import 'data/providers.dart';

/// Before the first frame: only the phone settings. The local database
/// opens in parallel; Supabase and Firebase start in the background, so
/// the network never delays Home. The student remembered on the phone is
/// signed in from the first frame.
void main() {
  runZonedGuarded(() async {
    startupTrace.mark('main');
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers();
    registerFontLicenses();
    final prefs = await SharedPreferences.getInstance();
    startupTrace.mark('settings read');
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    container.read(backendStartingProvider.notifier).set(true);
    unawaited(
      container
          .read(appDatabaseProvider)
          .warmUp()
          .then(
            (_) => startupTrace.mark('database open'),
            onError: (Object error, StackTrace stack) =>
                appLog.error(error, stack, reason: 'database warm-up'),
          ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startupTrace.mark('first frame');
      unawaited(
        initFirebase().then((_) => startupTrace.mark('firebase ready')),
      );
    });
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const KampusLinkApp(),
      ),
    );
    startupTrace.mark('runApp');
    unawaited(_startBackend(container));
  }, (error, stack) => appLog.error(error, stack, fatal: true, reason: 'zone'));
}

/// The client is set BEFORE the "starting" flag goes down, so the student
/// is never signed out in between. Firebase starts after the first frame.
Future<void> _startBackend(ProviderContainer container) async {
  final supabase = await initSupabase();
  startupTrace.mark('supabase ready');
  container.read(supabaseClientProvider.notifier).set(supabase);
  container.read(backendStartingProvider.notifier).set(false);
}
