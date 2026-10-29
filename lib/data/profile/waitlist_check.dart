import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/logging/logger.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../reminders/reminder_notifier.dart'
    show reminderLargeIcon, reminderSmallIcon;
import 'offers.dart';

/// Daily background check for waitlisted students (network required,
/// battery-friendly WorkManager job): when their speciality (+ year) is
/// offered, one local notification; tapping it opens onboarding with that
/// speciality pre-selected. Stopped after onboarding.
const waitlistTask = 'kampuslink.waitlist_check';
const waitlistPayload = 'waitlist';
const waitlistNotifiedKey = 'waitlist_notified_v1';
const _waitlistNotificationId = 7200;

bool waitlistNowOffered(OnboardingOffers offers, WaitlistEntry? entry) =>
    entry != null &&
    entry.specialityId != null &&
    offers.offers(entry.specialityId, entry.year);

({String title, String body}) waitlistTexts(
  String lang,
  String name,
) => switch (lang) {
  'ar' => (
    title:
        '$name \u0645\u062a\u0648\u0641\u0631 \u0627\u0644\u0622\u0646 \u0639\u0644\u0649 KampusLink',
    body: '\u0627\u0636\u063a\u0637 \u0644\u0627\u062e\u062a\u064a\u0627\u0631 \u0633\u0646\u062a\u0643 \u0648\u0627\u0644\u0628\u062f\u0621.',
  ),
  'en' => (
    title: '$name is now on KampusLink',
    body: 'Tap to choose your year and start.',
  ),
  _ => (
    title: '$name est maintenant sur KampusLink',
    body: 'Appuie pour choisir ton ann\u00e9e et commencer.',
  ),
};

/// Runs in a background isolate (WorkManager).
@pragma('vm:entry-point')
void waitlistCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await runWaitlistCheck();
    } catch (_) {
      // Never fail the job: it simply runs again tomorrow.
    }
    return true;
  });
}

Future<void> runWaitlistCheck() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final entry = readWaitlist(prefs);
  if (entry == null || (prefs.getBool(waitlistNotifiedKey) ?? false)) {
    return;
  }
  final client = await initSupabase();
  if (client == null || client.auth.currentSession == null) {
    return;
  }
  final raw = await client
      .rpc('get_onboarding_options')
      .timeout(const Duration(seconds: 30));
  if (raw is! Map) {
    return;
  }
  final offers = OnboardingOffers.fromMap(raw.cast<String, dynamic>());
  if (!waitlistNowOffered(offers, entry)) {
    return;
  }
  final texts = waitlistTexts(
    prefs.getString('ui_language') ?? 'fr',
    entry.name,
  );
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/$reminderSmallIcon'),
    ),
  );
  await plugin.show(
    _waitlistNotificationId,
    texts.title,
    texts.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'kampuslink_news',
        'KampusLink',
        importance: Importance.defaultImportance,
        icon: reminderSmallIcon,
        largeIcon: DrawableResourceAndroidBitmap(reminderLargeIcon),
        color: Color(0xFF3E7BFA),
      ),
    ),
    payload: waitlistPayload,
  );
  await prefs.setBool(waitlistNotifiedKey, true);
}

bool _workmanagerReady = false;

Future<void> _initWorkmanager() async {
  if (_workmanagerReady) {
    return;
  }
  await Workmanager().initialize(waitlistCallbackDispatcher);
  _workmanagerReady = true;
}

/// After join_waitlist (and at each start while waitlisted).
Future<void> scheduleWaitlistCheck() async {
  if (kIsWeb) {
    return;
  }
  try {
    await _initWorkmanager();
    await Workmanager().registerPeriodicTask(
      waitlistTask,
      waitlistTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (error) {
    appLog.warn('waitlist check not scheduled ($error)');
  }
}

/// After onboarding (or when there is nothing to wait for).
Future<void> cancelWaitlistCheck() async {
  if (kIsWeb) {
    return;
  }
  try {
    await _initWorkmanager();
    await Workmanager().cancelByUniqueName(waitlistTask);
  } catch (error) {
    appLog.warn('waitlist check not cancelled ($error)');
  }
}

/// Start of the app: the job runs only while there is a waitlist entry
/// not yet notified.
Future<void> syncWaitlistCheck(SharedPreferences prefs) async {
  final waiting =
      readWaitlist(prefs) != null &&
      !(prefs.getBool(waitlistNotifiedKey) ?? false);
  if (waiting) {
    await scheduleWaitlistCheck();
  } else {
    await cancelWaitlistCheck();
  }
}
