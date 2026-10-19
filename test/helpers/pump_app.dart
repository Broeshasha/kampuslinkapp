import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the whole app with fresh, empty local settings.
Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const KampusLinkApp(),
    ),
  );
  await tester.pumpAndSettle();
}
