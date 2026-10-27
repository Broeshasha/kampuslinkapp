import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/l10n/locale_controller.dart';
import '../../data/providers.dart';

enum OnboardingStatus { loading, needed, done }

String _flagKey(String uid) => 'onboarding_v1_done:$uid';
String _meKey(String uid) => 'me_cache_v1:$uid';
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, dynamic>? _cachedMe(SharedPreferences prefs, String uid) {
  final raw = prefs.getString(_meKey(uid));
  if (raw == null) return null;
  try {
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}

Future<void> _saveMe(
  SharedPreferences prefs,
  String uid,
  Map<String, dynamic> me,
) async {
  try {
    await prefs.setString(_meKey(uid), jsonEncode(me));
    if (_int(me['onboarding_version']) >= 1) {
      await prefs.setBool(_flagKey(uid), true);
    }
  } catch (_) {
    // A cache write must never break the profile.
  }
}

/// get_me() of the signed-in student (null when signed out / no backend).
/// Saved on the phone: when the network fails the saved copy is returned,
/// so a dead network never sends anyone to sign-in or onboarding.
final meProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = ref.watch(authControllerProvider.select((a) => a.userId));
  final api = ref.watch(kampusApiProvider);
  if (uid == null || api == null) return null;
  final prefs = ref.read(sharedPrefsProvider);
  try {
    final me = await api.getMe();
    if (me != null) await _saveMe(prefs, uid, me);
    return me;
  } catch (_) {
    final cached = _cachedMe(prefs, uid);
    if (cached != null) return cached;
    rethrow;
  }
});

final onboardingOptionsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final api = ref.watch(kampusApiProvider);
  if (api == null) throw const ServerFailure('supabase_not_ready');
  return api.getOnboardingOptions();
});

/// Signed out -> needed. Signed in + remembered -> done (works offline).
/// Otherwise get_me(): onboarding_version >= 1 -> done (old accounts have 0
/// and see the new onboarding once). A FAILED get_me() (offline, timeout,
/// 5xx) -> done: failures never route to onboarding.
final onboardingStatusProvider = Provider<OnboardingStatus>((ref) {
  final uid = ref.watch(authControllerProvider.select((a) => a.userId));
  if (uid == null) return OnboardingStatus.needed;
  if (ref.read(sharedPrefsProvider).getBool(_flagKey(uid)) ?? false) {
    return OnboardingStatus.done;
  }
  final me = ref.watch(meProvider);
  if (me.hasValue) {
    final value = me.requireValue;
    return value != null && _int(value['onboarding_version']) >= 1
        ? OnboardingStatus.done
        : OnboardingStatus.needed;
  }
  if (me.hasError) {
    return mapError(me.error!) is OnboardingRequiredFailure
        ? OnboardingStatus.needed
        : OnboardingStatus.done;
  }
  return OnboardingStatus.loading;
});

Future<void> markOnboardingDone(WidgetRef ref, String? uid) async {
  if (uid != null) {
    await ref.read(sharedPrefsProvider).setBool(_flagKey(uid), true);
  }
  ref.invalidate(onboardingStatusProvider);
}
