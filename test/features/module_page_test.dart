import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/features/modules/module_page.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/lesson_repository_test.dart' show moduleBundle;

/// The module page in its states: not downloaded (offline), no lessons yet,
/// and downloaded (lessons grouped by chapter).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  Future<void> pumpModule(WidgetTester tester, {bool online = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWith((ref) => Stream.value(online)),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ModulePage(moduleId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Future<void> addModule(WidgetTester tester, {required int serverVersion}) =>
      tester.runAsync(
        () => db
            .into(db.modules)
            .insert(
              ModulesCompanion.insert(
                id: const Value(7),
                name: 'Chimie',
                serverVersion: Value(serverVersion),
              ),
            ),
      );

  testWidgets('not downloaded + offline: says to connect', (tester) async {
    await addModule(tester, serverVersion: 3);
    await pumpModule(tester, online: false);
    expect(find.text('This module is not downloaded yet'), findsOneWidget);
    expect(
      find.text('Connect to the internet to download it.'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('no content on the server yet: friendly message', (tester) async {
    await addModule(tester, serverVersion: 0);
    await pumpModule(tester);
    expect(
      find.text('No lessons yet for this module. They are coming soon.'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('downloaded: lessons grouped by chapter, in order', (
    tester,
  ) async {
    await tester.runAsync(
      () => BundleImporter(db).importBundle(moduleBundle()),
    );
    await pumpModule(tester, online: false);
    expect(find.text('Lecon 11'), findsOneWidget);
    expect(find.text('Lecon 13'), findsOneWidget);
    expect(find.text('Chapter 1 \u00b7 Chapitre 1'), findsOneWidget);
    expect(find.text('Chapter 2 \u00b7 Chapitre 2'), findsOneWidget);
    await finish(tester);
  });
}
