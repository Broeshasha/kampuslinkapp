import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Requests notification permission (required explicitly on Android 13+,
/// otherwise push notifications are silently never shown), fetches the
/// device's FCM token, and saves it to the user's profile so the backend
/// has something to actually send a push to.
class NotificationService {
  NotificationService._();

  static Future<String?> requestPermissionAndGetToken() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $token');
      if (token != null) await _saveToken(token);

      // FCM tokens rotate over time (reinstall, cleared app data, token
      // expiry). Without this listener, a rotated token never gets saved
      // and push notifications quietly stop working for that user.
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      return token;
    } catch (e) {
      debugPrint('FCM token fetch error: $e');
      return null;
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('FCM token saved to profile');
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  /// Call on sign-out so a logged-out device stops being a valid push
  /// target -- otherwise a stale token could still receive notifications
  /// meant for whoever's account is active next on a shared device.
  static Future<void> clearToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);
    } catch (e) {
      debugPrint('FCM token clear error: $e');
    }
  }
}
