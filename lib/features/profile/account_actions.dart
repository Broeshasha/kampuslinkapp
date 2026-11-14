import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../data/local_data.dart';
import '../../data/providers.dart';

export '../../data/local_data.dart' show keptPrefs, wipeLocalData;

/// Sign out (B01): send the work still waiting (one try, 15 s), stop this
/// phone's push messages (unregister_push_token), end the session, then
/// wipe the phone. If work could not be sent (offline) the data stays: the
/// same student gets it back at the next sign-in; another student's
/// sign-in wipes it before anything is sent. Never throws.
Future<void> signOutEverywhere(WidgetRef ref) async {
  final api = ref.read(kampusApiProvider);
  final db = ref.read(appDatabaseProvider);
  final prefs = ref.read(sharedPrefsProvider);
  final outbox = ref.read(outboxRepositoryProvider);
  final outboxSync = ref.read(outboxSyncProvider);
  if (outboxSync != null) {
    await guard(() => outboxSync.flush().timeout(const Duration(seconds: 15)));
  }
  if (api != null && !kIsWeb && Firebase.apps.isNotEmpty) {
    await guard(() async {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
      );
      if (token != null) await api.unregisterPushToken(token);
    });
  }
  await guard(ref.read(authRepositoryProvider).signOut);
  final pending = await guard(() => outbox.watchPendingCount().first);
  if (pending case Ok(:final value) when value == 0) {
    await guard(() => wipeLocalData(db, prefs));
  }
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
