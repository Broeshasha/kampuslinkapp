import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/auth/auth_controller.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/features/home/home_page.dart';
import 'package:kampuslink/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth.dart';

void main() {
  testWidgets('airplane-mode cold start, expired token -> Home, not sign-in', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    SharedPreferences.setMockInitialValues({'onboarding_v1_done:u1': true});
    final prefs = await SharedPreferences.getInstance();
    final gw = FakeAuthGateway(expiredUser);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          appDatabaseProvider.overrideWithValue(db),
          authGatewayProvider.overrideWithValue(gw),
        ],
        child: const KampusLinkApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(gw.signOutCalls, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
