import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/app_failure.dart';
import '../../core/l10n/locale_controller.dart';
import '../../data/providers.dart';

enum OnboardingStatus { loading, needed, done }

String _flagKey(String uid) => 'onboarding_v1_done:$uid';
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// get_me() of the signed-in student (null when signed out / no backend).
/// When the server says onboarding v1 is done, the phone remembers it so the
/// app opens offline next time.
final meProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final signedIn = ref.watch(isSignedInProvider);
  final api = ref.watch(kampusApiProvider);
  if (!signedIn || api == null) return null;
  final me = await api.getMe();
  final uid = me?['id']?.toString();
  if (me != null && uid != null && _int(me['onboarding_version']) >= 1) {
    await ref.read(sharedPrefsProvider).setBool(_flagKey(uid), true);
  }
  return me;
});

final onboardingOptionsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final api = ref.watch(kampusApiProvider);
  if (api == null) throw const ServerFailure('supabase_not_ready');
  return api.getOnboardingOptions();
});

/// Signed out -> needed. Signed in + remembered -> done (works offline).
/// Otherwise ask get_me(): onboarding_version >= 1 -> done (old accounts
/// have 0 and see the new onboarding once).
final onboardingStatusProvider = Provider<OnboardingStatus>((ref) {
  if (!ref.watch(isSignedInProvider)) return OnboardingStatus.needed;
  final uid = ref.watch(authRepositoryProvider).session?.user.id;
  if (uid != null &&
      (ref.read(sharedPrefsProvider).getBool(_flagKey(uid)) ?? false)) {
    return OnboardingStatus.done;
  }
  return switch (ref.watch(meProvider)) {
    AsyncData(:final value) =>
      value != null && _int(value['onboarding_version']) >= 1
          ? OnboardingStatus.done
          : OnboardingStatus.needed,
    AsyncError() => OnboardingStatus.needed,
    _ => OnboardingStatus.loading,
  };
});

Future<void> markOnboardingDone(WidgetRef ref, String? uid) async {
  if (uid != null) {
    await ref.read(sharedPrefsProvider).setBool(_flagKey(uid), true);
  }
  ref.invalidate(onboardingStatusProvider);
}
