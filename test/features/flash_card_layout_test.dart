import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/home/flash_card.dart';

import '../helpers/pump_in_app.dart';

void main() {
  testWidgets('card uses the full width; like/save/report sit on the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final liked = <bool>[];
    var reports = 0;
    await pumpInApp(
      tester,
      FlashCardView(
        front: 'What is an oxide?',
        back: 'Oxygen + another element',
        language: 'en',
        moduleName: 'Chimie',
        accent: Colors.blue,
        onAnswer: (_) {},
        onLike: liked.add,
        onReport: () => reports++,
      ),
    );
    expect(tester.takeException(), isNull);
    // The footer is centred on the whole phone width (no side column).
    final hint = tester.getRect(find.text('Tap to see the answer'));
    expect(hint.center.dx, closeTo(160, 12));
    // The buttons are inside the screen, stacked on the same column.
    final like = tester.getRect(find.byTooltip('Like'));
    final save = tester.getRect(find.byTooltip('Save'));
    final report = tester.getRect(find.byTooltip('Report a mistake'));
    expect(like.right, lessThanOrEqualTo(320));
    expect(save.center.dx, closeTo(like.center.dx, 1));
    expect(report.top, greaterThan(save.top));
    expect(save.top, greaterThan(like.top));
    await tester.tap(find.byTooltip('Like'));
    await tester.tap(find.byTooltip('Report a mistake'));
    await tester.pump();
    expect(liked, [true]);
    expect(reports, 1);
    // Tapping a button does not flip the card.
    expect(find.text('What is an oxide?'), findsOneWidget);
  });
}
