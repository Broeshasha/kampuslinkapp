import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/result.dart';
import '../../core/logging/logger.dart';
import '../providers.dart';
import '../reminders/reminder_controller.dart';

/// MOT-3 PUSH: the phone gives its Firebase token to the server so the
/// kl-push Worker can remind students whose phone killed the local
/// reminders. Sent again only when the token or the account changes.
/// Reminders off -> token removed (the server also checks "stop").
const _sentKey = 'push_token_sent_v1';
StreamSubscription<String>? _refreshSub;

/// Call from widgets: `ref.read(pushTokenSyncProvider)()`.
final pushTokenSyncProvider = Provider<Future<void> Function()>(
  (ref) => () => syncPushToken(ref),
);

Future<void> syncPushToken(Ref ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final uid = ref.read(authControllerProvider).userId;
  final api = ref.read(kampusApiProvider);
  if (uid == null || api == null || !ref.read(isOnlineProvider)) return;
  final prefs = ref.read(sharedPrefsProvider);
  final active = ref.read(reminderControllerProvider)?.active ?? false;
  final r = await guard(() async {
    final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 10));
    if (token == null) return;
    if (!active) {
      if (prefs.getString(_sentKey) != null) {
        await api.unregisterPushToken(token);
        await prefs.remove(_sentKey);
      }
      return;
    }
    final mark = '$uid|$token';
    if (prefs.getString(_sentKey) == mark) return;
    await api.registerPushToken(token);
    await prefs.setString(_sentKey, mark);
  });
  if (r case Err(:final failure)) appLog.warn('push token: $failure');
  _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
    await prefs.remove(_sentKey);
    await syncPushToken(ref);
  });
}

/// Before sign-out (still signed in): this phone stops getting pushes for
/// the account that leaves. Never blocks the sign-out.
Future<void> dropPushToken(Future<void> Function(String token) unregister) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
    if (token != null) await unregister(token).timeout(const Duration(seconds: 5));
    await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 5));
  } catch (error) {
    appLog.warn('push token drop: $error');
  }
}
