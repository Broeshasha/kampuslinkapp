import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/features/profile/language_picker.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('starts on Home in English on an English phone', (tester) async {
    await pumpApp(tester);
    expect(find.text('KampusLink'), findsOneWidget);
    expect(find.text('Study smarter. Even offline.'), findsOneWidget);
  });

  testWidgets('switching to Arabic is instant and right-to-left', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u0627\u0644\u0639\u0631\u0628\u064a\u0629'));
    await tester.pumpAndSettle();
    final dir = Directionality.of(tester.element(find.byType(LanguagePicker)));
    expect(dir, TextDirection.rtl);
  });

  test('unsupported phone language falls back to French', () {
    expect(resolveLocale(const [Locale('de')], const []), const Locale('fr'));
    expect(
      resolveLocale(const [Locale('de'), Locale('ar', 'DZ')], const []),
      const Locale('ar'),
    );
  });
}
