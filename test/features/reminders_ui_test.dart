import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/profile/study_level.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/data/reminders/reminder_controller.dart';
import 'package:kampuslink/data/reminders/reminder_notifier.dart';
import 'package:kampuslink/data/reminders/reminder_texts.dart';
import 'package:kampuslink/features/home/flash_card.dart';
import 'package:kampuslink/features/reminders/reminder_step.dart';
import 'package:kampuslink/features/reminders/reminders_page.dart';
import 'package:kampuslink/features/reminders/review_session_page.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Phone implements ReminderNotifier {
  _Phone({this.allowed = true});

  final bool allowed;
  int asked = 0;

  @override
  Future<void> init(void Function(String?, String?) onTap) async {}

  @override
  Future<bool> enabled() async => allowed;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(List<ReminderSlot> slots, ReminderTexts texts) async {}

  @override
  Future<String?> launchPayload() async => null;
}

Future<AppDatabase> _db(WidgetTester tester, {bool cards = false}) async {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  if (cards) {
    await tester.runAsync(
      () => BundleImporter(db).importBundle({
        'schema_version': 3,
        'module': {'id': 7, 'name': 'Stats', 'semester': 3},
        'version': 1,
        'languages': ['fr'],
        'lessons': [
          {
            'id': 1,
            'position': 1,
            'i18n': {
              'fr': {'title': 'L1'},
            },
            'cards': [
              {
                'id': 11,
                'position': 1,
                'i18n': {
                  'fr': {'front': 'Question un', 'back': 'Reponse un'},
                },
              },
            ],
            'questions': const [],
          },
        ],
        'resources': const [],
        'glossary': const [],
        'sets': const [],
      }),
    );
  }
  return db;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required AppDatabase db,
  required ReminderNotifier phone,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        appDatabaseProvider.overrideWithValue(db),
        reminderNotifierProvider.overrideWithValue(phone),
        currentSemesterProvider.overrideWithValue(3),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _end(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('onboarding step: Skip changes nothing', (tester) async {
    final db = await _db(tester);
    var done = 0;
    await _pump(
      tester,
      ReminderStep(onDone: () => done++),
      db: db,
      phone: _Phone(),
    );
    expect(find.text('When do you want to study?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(done, 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReminderStep)),
    );
    expect(container.read(reminderControllerProvider), isNull);
    await _end(tester, db);
  });

  testWidgets('onboarding step: Allow saves and asks the permission', (
    tester,
  ) async {
    final db = await _db(tester);
    final phone = _Phone();
    var done = 0;
    await _pump(
      tester,
      ReminderStep(onDone: () => done++),
      db: db,
      phone: phone,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReminderStep)),
    );
    await tester.tap(find.text('Allow notifications'));
    await _settle(tester);
    expect(phone.asked, 1);
    expect(container.read(reminderControllerProvider)?.enabled, isTrue);
    expect(done, 1);
    await _end(tester, db);
  });

  testWidgets('Reminders page explains how to enable blocked notifications', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(
      tester,
      const RemindersPage(),
      db: db,
      phone: _Phone(allowed: false),
    );
    await _settle(tester);
    expect(find.textContaining('Settings > Apps > KampusLink'), findsOneWidget);
    await _end(tester, db);
  });

  testWidgets('Start opens a 10-minute review of the phone cards', (
    tester,
  ) async {
    final db = await _db(tester, cards: true);
    await _pump(tester, const ReviewSessionPage(), db: db, phone: _Phone());
    await _settle(tester);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.byType(FlashCardView), findsOneWidget);
    await _end(tester, db);
  });
}
