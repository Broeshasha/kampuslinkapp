import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/profile/language_picker.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('signed out: settings work and the theme can be forced dark', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text('Continue with Google'), findsWidgets);
    final dark = find.text('Dark');
    await tester.ensureVisible(dark);
    await tester.pumpAndSettle();
    await tester.tap(dark);
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(LanguagePicker)));
    expect(theme.brightness, Brightness.dark);
    await tester.ensureVisible(find.text('Send feedback'));
    expect(find.textContaining('Version'), findsOneWidget);
    expect(find.text('Delete my account'), findsNothing);
  });
}
