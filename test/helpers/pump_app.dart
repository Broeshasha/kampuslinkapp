import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the whole app with fresh, empty local settings.
/// [online] fakes the network state (no real plugin in tests).
Future<void> pumpApp(WidgetTester tester, {bool online = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: const KampusLinkApp(),
    ),
  );
  await tester.pumpAndSettle();
}
