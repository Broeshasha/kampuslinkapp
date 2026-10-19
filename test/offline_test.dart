import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/ui/offline_banner.dart';

import 'helpers/pump_app.dart';

const _offlineText = "You're offline \u00b7 showing what's saved on your phone";

void main() {
  testWidgets('no banner while online', (tester) async {
    await pumpApp(tester);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text(_offlineText), findsNothing);
  });

  testWidgets('offline banner shows, and fits a tiny phone at 1.5x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, online: false);
    expect(find.text(_offlineText), findsOneWidget);
    for (final icon in [Icons.grid_view_outlined, Icons.person_outline]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
