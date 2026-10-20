import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';

/// Settings that survive a sign-out or an account deletion.
const keptPrefs = {'ui_language', 'theme_mode', 'reader_scale_step'};

/// Empties every local table and forgets everything but the device
/// settings (language, theme, text size).
Future<void> wipeLocalData(AppDatabase db, SharedPreferences prefs) async {
  await db.transaction(() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
  });
  for (final key in prefs.getKeys().toList()) {
    if (!keptPrefs.contains(key)) await prefs.remove(key);
  }
}

/// Sign out: stop this phone's push messages first (unregister_push_token),
/// then end the session. Never throws.
Future<void> signOutEverywhere(WidgetRef ref) async {
  final api = ref.read(kampusApiProvider);
  if (api != null && !kIsWeb && Firebase.apps.isNotEmpty) {
    await guard(() async {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
      );
      if (token != null) await api.unregisterPushToken(token);
    });
  }
  await guard(ref.read(authRepositoryProvider).signOut);
}

/// delete_my_account (store policy), then wipe the phone and sign out.
/// Returns the failure when the server refused or was unreachable.
Future<AppFailure?> deleteAccount(WidgetRef ref) async {
  final api = ref.read(kampusApiProvider);
  if (api == null) return const OfflineFailure();
  final result = await guard(api.deleteMyAccount);
  if (result case Err(:final failure)) return failure;
  final db = ref.read(appDatabaseProvider);
  final prefs = ref.read(sharedPrefsProvider);
  await guard(() => wipeLocalData(db, prefs));
  await guard(ref.read(authRepositoryProvider).signOut);
  return null;
}
