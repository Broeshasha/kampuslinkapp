import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/profile/offers.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/features/onboarding/onboarding_status.dart';
import 'package:kampuslink/features/onboarding/studies_step.dart';
import 'package:kampuslink/features/profile/study_profile_page.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _level(String year, int position, List<int> semesters) => {
  'year': year,
  'position': position,
  'semesters': semesters,
  'label': {'en': year, 'fr': year, 'ar': year},
};

/// 2 offered specialities (Mining L2/L3 with semesters, Medicine unified
/// with no semesters) and one that is not offered yet.
Map<String, dynamic> _payload({bool waitlisted = false}) => {
  'universities': [
    {'id': 1, 'name': 'Constantine 3'},
  ],
  'specialities': [
    {
      'id': 2,
      'name': 'Mining engineering',
      'year_system': 'lmd',
      'learn_enabled': true,
      'levels': [
        _level('L3', 2, [5, 6]),
        _level('L2', 1, [3, 4]),
      ],
    },
    {
      'id': 9,
      'name': 'Medicine',
      'year_system': 'unified',
      'learn_enabled': true,
      'levels': [_level('Y1', 1, [])],
    },
  ],
  'other_specialities': [
    {'id': 5, 'name': 'Architecture'},
  ],
  'waitlisted': waitlisted,
};

class _FakeStudies implements StudiesApi {
  final calls = <(int, String, int?)>[];

  @override
  Future<void> joinWaitlist({
    int? specialityId,
    String? specialityText,
    String? year,
    int? universityId,
  }) async {}

  @override
  Future<Map<String, dynamic>> setStudyProfile({
    required int specialityId,
    required String year,
    int? semester,
  }) async {
    calls.add((specialityId, year, semester));
    return {'semester': semester, 'academic_year': year};
  }
}

Future<AppDatabase> _pump(
  WidgetTester tester,
  Widget child, {
  Map<String, dynamic>? payload,
  Map<String, Object> prefs = const {},
  StudiesApi? api,
}) async {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        appDatabaseProvider.overrideWithValue(db),
        onboardingOptionsProvider.overrideWith(
          (ref) async => payload ?? _payload(),
        ),
        if (api != null) studiesApiProvider.overrideWithValue(api),
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
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  return db;
}

Future<void> _end(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(db.close);
}

Future<void> _pick(WidgetTester tester, Key dropdown, String item) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  test('offers: only offered specialities and years, sorted', () {
    final o = OnboardingOffers.fromMap(_payload());
    expect(o.specialities.map((s) => s.name), [
      'Mining engineering',
      'Medicine',
    ]);
    expect(o.speciality(2)!.levels.map((l) => l.year), ['L2', 'L3']);
    expect(o.speciality(9)!.levels.single.semesters, isEmpty);
    expect(o.offers(2, 'L3'), isTrue);
    expect(o.offers(2, 'M1'), isFalse);
    expect(o.offers(5, null), isFalse);
    expect(o.others.single.name, 'Architecture');
  });

  testWidgets('onboarding: years and semesters come from the offer', (
    tester,
  ) async {
    final db = await _pump(tester, StudiesStep(onDone: () {}));
    await _pick(tester, const ValueKey('speciality'), 'Mining engineering');
    expect(find.byKey(const ValueKey('year-L2')), findsOneWidget);
    expect(find.byKey(const ValueKey('year-L3')), findsOneWidget);
    expect(find.byKey(const ValueKey('semester-3')), findsOneWidget);
    await _pick(tester, const ValueKey('speciality'), 'Medicine');
    expect(find.byKey(const ValueKey('year-Y1')), findsOneWidget);
    expect(find.byKey(const ValueKey('semester-3')), findsNothing);
    await _end(tester, db);
  });

  testWidgets('onboarding: not listed -> waitlist form', (tester) async {
    final db = await _pump(tester, StudiesStep(onDone: () {}));
    await tester.tap(find.text("My speciality isn't listed"));
    await tester.pumpAndSettle();
    expect(find.text('Which speciality do you study?'), findsOneWidget);
    expect(find.text('Tell me when it\'s ready'), findsOneWidget);
    await _end(tester, db);
  });

  testWidgets('waitlisted and still not offered: Coming soon again', (
    tester,
  ) async {
    final db = await _pump(
      tester,
      StudiesStep(onDone: () {}),
      payload: _payload(waitlisted: true),
      prefs: {
        waitlistKey: jsonEncode(
          const WaitlistEntry(specialityId: 5, name: 'Architecture').toJson(),
        ),
      },
    );
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.textContaining('Architecture'), findsOneWidget);
    await _end(tester, db);
  });

  testWidgets(
    'Profile > My studies: change year, sent with set_study_profile',
    (tester) async {
      final api = _FakeStudies();
      final db = await _pump(tester, const StudyProfilePage(), api: api);
      await tester.tap(find.text('L3'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(api.calls, [(2, 'L3', 5)]);
      await _end(tester, db);
    },
  );
}
