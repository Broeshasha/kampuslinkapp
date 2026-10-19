import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('signed out: Modules shows a friendly sign-in prompt', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to download your modules'), findsOneWidget);
    expect(find.text('Continue with Google'), findsWidgets);
  });
}
