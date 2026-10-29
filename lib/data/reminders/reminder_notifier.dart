import 'dart:async';
import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_texts.dart';

const reminderActionStart = 'start';
const reminderActionNotNow = 'not_now';

/// "Not now" tapped while the app is closed: written here, read by the app
/// at its next start (ReminderController drains it).
const reminderInboxKey = 'reminder_inbox_v1';

/// Notification ids reserved for study reminders.
const reminderFirstId = 7100;
const reminderMaxSlots = 12;

/// Runs in a background isolate when "Not now" is tapped.
@pragma('vm:entry-point')
Future<void> reminderBackgroundTap(NotificationResponse response) async {
  if (response.actionId != reminderActionNotNow) {
    return;
  }
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final inbox = prefs.getStringList(reminderInboxKey) ?? <String>[];
  inbox.add('${response.payload ?? ''}|$reminderActionNotNow');
  await prefs.setStringList(reminderInboxKey, inbox);
}

class ReminderSlot {
  const ReminderSlot({
    required this.id,
    required this.at,
    required this.body,
    required this.payload,
    this.title = reminderTitle,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String payload;
}

/// White one-colour silhouette of the logo (never the colour launcher
/// icon, which Android shows as a grey square) + the colour logo.
const reminderSmallIcon = 'ic_stat_kampuslink';
const reminderLargeIcon = 'ic_large_kampuslink';

/// The phone side of reminders (a fake in tests).
abstract interface class ReminderNotifier {
  /// [onTap] gets the payload and the action id (null = the notification).
  Future<void> init(void Function(String? payload, String? action) onTap);
  Future<bool> enabled();
  Future<bool> requestPermission();
  Future<void> cancelAll();
  Future<void> schedule(List<ReminderSlot> slots, ReminderTexts texts);

  /// The payload when the app was opened by tapping a reminder.
  Future<String?> launchPayload();
}

/// flutter_local_notifications, inexact (a few minutes late is fine), no
/// exact alarms, no full-screen intent, normal notification sound.
class LocalReminderNotifier implements ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  tz.Location? _algiers;
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init(
    void Function(String? payload, String? action) onTap,
  ) async {
    if (_ready || kIsWeb) {
      return;
    }
    tzdata.initializeTimeZones();
    _algiers = tz.getLocation('Africa/Algiers');
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/$reminderSmallIcon'),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload, r.actionId),
      onDidReceiveBackgroundNotificationResponse: reminderBackgroundTap,
    );
    _ready = true;
  }

  @override
  Future<bool> enabled() async {
    if (!_ready) {
      return false;
    }
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) {
      return false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) {
      return;
    }
    for (var i = 0; i < reminderMaxSlots; i++) {
      await _plugin.cancel(reminderFirstId + i);
    }
  }

  @override
  Future<void> schedule(List<ReminderSlot> slots, ReminderTexts texts) async {
    final algiers = _algiers;
    if (!_ready || algiers == null) {
      return;
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'study_reminders',
        texts.channelName,
        channelDescription: texts.channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: reminderSmallIcon,
        largeIcon: const DrawableResourceAndroidBitmap(reminderLargeIcon),
        color: const Color(0xFF3E7BFA),
        actions: [
          AndroidNotificationAction(
            reminderActionStart,
            texts.start,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            reminderActionNotNow,
            texts.notNow,
            cancelNotification: true,
          ),
        ],
      ),
    );
    for (final s in slots) {
      await _plugin.zonedSchedule(
        s.id,
        s.title,
        s.body,
        tz.TZDateTime.from(s.at, algiers),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: s.payload,
      );
    }
  }

  @override
  Future<String?> launchPayload() async {
    if (!_ready) {
      return null;
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return details.notificationResponse?.payload;
  }
}
