import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// P1-ANALYTICS: growth numbers, privacy-safe (BAC_LAUNCH_PLAN 0.4).
/// Rules: never setUserId; never names, emails, usernames, free text or the
/// wilaya of one student. User properties only: track, stream, year, ui_lang.
/// Advertising ID, SSAID and ad personalization are off in AndroidManifest.
/// Never throws, never blocks: no Firebase (web, tests, init failed) = no-op.
class Analytics {
  Analytics._();

  /// The only events the app may send.
  static const events = {
    'onboarding_start',
    'onboarding_complete',
    'module_download_complete',
    'lesson_complete',
    'quiz_complete',
    'cards_session',
    'exam_complete',
    'streak_day',
    'shop_buy',
    'duel_start',
    'duel_finish',
    'push_open',
  };

  static const userProps = {'track', 'stream', 'year', 'ui_lang'};

  static FirebaseAnalytics? get _fa {
    if (kIsWeb) return null;
    try {
      return Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Logs [name] (must be in [events]) with numbers / short codes only.
  static Future<void> log(String name, [Map<String, Object>? params]) async {
    assert(events.contains(name), 'unknown analytics event $name');
    final fa = _fa;
    if (fa == null || !events.contains(name)) return;
    try {
      await fa.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics must never break the app.
    }
  }

  /// Sets the allowed user properties (null values are skipped).
  static Future<void> setUser({
    String? track,
    String? stream,
    String? year,
    String? uiLang,
  }) async {
    final fa = _fa;
    if (fa == null) return;
    final props = {
      'track': track,
      'stream': stream,
      'year': year,
      'ui_lang': uiLang,
    };
    try {
      for (final e in props.entries) {
        final v = e.value;
        if (v != null && v.isNotEmpty) {
          await fa.setUserProperty(name: e.key, value: v);
        }
      }
    } catch (_) {
      // never fatal
    }
  }

  /// Score bucket (0-49, 50-79, 80-100) instead of exact numbers.
  static String scoreBucket(int score) => score >= 80
      ? '80_100'
      : score >= 50
      ? '50_79'
      : '0_49';
}
