import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/notifications/notifications_screen.dart';
import '../../features/messages/chat_screen.dart';

/// Global so a notification tap can navigate even when it happens outside
/// any widget's BuildContext -- e.g. a cold-start tap fires before any
/// screen has built yet.
final rootNavigatorKey = GlobalKey<NavigatorState>();

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
      if (token != null) {
        await _saveToken(token);
        await _subscribeToUniversityTopic();
      }

      // FCM tokens rotate over time (reinstall, cleared app data, token
      // expiry). Without this listener, a rotated token never gets saved
      // and push notifications quietly stop working for that user.
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      _setupTapHandling();

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

  /// Subscribes this device to its university's broadcast topic so it
  /// gets pushed every new home-feed post for that campus. Safe to call
  /// repeatedly -- Firebase just re-confirms an existing subscription.
  static Future<void> _subscribeToUniversityTopic() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('university_id')
          .eq('id', userId)
          .maybeSingle();

      final universityId = profile?['university_id'];
      if (universityId == null) return;

      await FirebaseMessaging.instance.subscribeToTopic('uni_$universityId');
      debugPrint('Subscribed to uni_$universityId');
    } catch (e) {
      debugPrint('Topic subscribe error: $e');
    }
  }

  /// Wires up both tap paths: a tap while the app is backgrounded (fires
  /// immediately) and a tap that cold-started the app (must be checked
  /// once, since there is no live stream event for it).
  static Future<void> _setupTapHandling() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _routeFromMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
  }

  static void _routeFromMessage(RemoteMessage message) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    final data = message.data;
    final type = data['type'];

    if (type == 'message') {
      final actorId = data['actor_id'];
      final actorUsername = data['actor_username'];
      if (actorId == null || actorId.isEmpty) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: actorId,
            otherUsername: actorUsername ?? 'User',
          ),
        ),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}
