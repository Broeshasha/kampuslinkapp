import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/app/app.dart';
import 'package:kampuslink/core/auth/auth_controller.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth.dart';

void main() {
  testWidgets('Modules: drawn from the phone with no network at all', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await tester.runAsync(
      () => BundleImporter(db).importBundle({
        'schema_version': 3,
        'module': {'id': 7, 'name': 'Ondes et vibrations', 'semester': 3},
        'version': 1,
        'languages': ['fr'],
        'lessons': const [],
        'resources': const [],
        'glossary': const [],
        'sets': const [],
      }),
    );
    SharedPreferences.setMockInitialValues({'onboarding_v1_done:u1': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          appDatabaseProvider.overrideWithValue(db),
          authGatewayProvider.overrideWithValue(FakeAuthGateway(expiredUser)),
        ],
        child: const KampusLinkApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Ondes et vibrations'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
