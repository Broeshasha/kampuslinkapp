import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/profile/language_picker.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('a new student starts on Welcome and can switch language', (
    tester,
  ) async {
    await pumpApp(tester, onboardingDone: false);
    expect(find.text('Study smarter. Even offline.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('\u0627\u0644\u0639\u0631\u0628\u064a\u0629'));
    await tester.pumpAndSettle();
    final dir = Directionality.of(tester.element(find.byType(LanguagePicker)));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('Next leads to the Google step, Back returns', (tester) async {
    await pumpApp(tester, onboardingDone: false);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Save your progress'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('onboarding fits a tiny phone at 1.5x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, onboardingDone: false);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
