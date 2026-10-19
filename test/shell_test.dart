import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/modules/modules_page.dart';

import 'helpers/pump_app.dart';

/// The 5 reference screens (dp) from the plan, at normal and 1.5x text.
const screens = [
  Size(320, 568),
  Size(360, 800),
  Size(412, 915),
  Size(768, 1024),
  Size(1280, 800),
];

void main() {
  for (final size in screens) {
    for (final scale in [1.0, 1.5]) {
      final name = '${size.width.toInt()}x${size.height.toInt()} text x$scale';
      testWidgets('all 3 tabs fit without overflow at $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester);
        for (final icon in [
          Icons.grid_view_outlined,
          Icons.person_outline,
          Icons.style_outlined,
        ]) {
          await tester.tap(find.byIcon(icon));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (size.width < 600) {
          expect(find.byType(NavigationBar), findsOneWidget);
        } else {
          expect(find.byType(NavigationRail), findsOneWidget);
        }
      });
    }
  }

  testWidgets('a tab stays alive when you switch away', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(ModulesPage, skipOffstage: false), findsOneWidget);
  });
}
