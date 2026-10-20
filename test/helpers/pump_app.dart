import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/features/onboarding/onboarding_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the whole app with fresh, empty local settings.
/// [online] fakes the network; [onboardingDone] skips (or shows) onboarding.
Future<void> pumpApp(
  WidgetTester tester, {
  bool online = true,
  bool onboardingDone = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        onboardingStatusProvider.overrideWithValue(
          onboardingDone ? OnboardingStatus.done : OnboardingStatus.needed,
        ),
      ],
      child: const KampusLinkApp(),
    ),
  );
  await tester.pumpAndSettle();
}
