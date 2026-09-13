$path = "C:\kampuslink\lib\core\config\notification_service.dart"
$content = Get-Content $path -Raw

$old1 = @'
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
'@

$new1 = @'
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
'@

if (-not $content.Contains($old1)) { Write-Host "ABORT: imports anchor not found"; exit }
$content = $content.Replace($old1, $new1)

$old2 = @'
      // FCM tokens rotate over time (reinstall, cleared app data, token
      // expiry). Without this listener, a rotated token never gets saved
      // and push notifications quietly stop working for that user.
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      return token;
'@

$new2 = @'
      // FCM tokens rotate over time (reinstall, cleared app data, token
      // expiry). Without this listener, a rotated token never gets saved
      // and push notifications quietly stop working for that user.
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      _setupTapHandling();

      return token;
'@

if (-not $content.Contains($old2)) { Write-Host "ABORT: token-refresh anchor not found"; exit }
$content = $content.Replace($old2, $new2)

$old3 = @'
      await FirebaseMessaging.instance.subscribeToTopic('uni_$universityId');
      debugPrint('Subscribed to uni_$universityId');
    } catch (e) {
      debugPrint('Topic subscribe error: $e');
    }
  }
}
'@

$new3 = @'
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

    // Every other type (like, comment_like, comment, reply, new_post):
    // no dedicated post-detail screen exists yet, so route to the full
    // Notifications list rather than guessing at a destination.
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}
'@

if (-not $content.Contains($old3)) { Write-Host "ABORT: class-closing anchor not found"; exit }
$content = $content.Replace($old3, $new3)

Set-Content -Path $path -Value $content -NoNewline
Write-Host "notification_service.dart patched with tap routing."