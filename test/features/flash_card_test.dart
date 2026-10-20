import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/home/flash_card.dart';

import '../helpers/pump_in_app.dart';

void main() {
  testWidgets('tap flips the card; the back answers once', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final answers = <bool>[];
    await pumpInApp(
      tester,
      FlashCardView(
        front: 'What is an oxide?',
        back: 'Oxygen + another element',
        language: 'en',
        moduleName: 'Chimie',
        accent: Colors.blue,
        onAnswer: answers.add,
      ),
    );
    expect(find.text('What is an oxide?'), findsOneWidget);
    expect(find.text('Tap to see the answer'), findsOneWidget);
    await tester.tap(find.text('What is an oxide?'));
    await tester.pumpAndSettle();
    expect(find.text('Oxygen + another element'), findsOneWidget);
    await tester.tap(find.text('I knew it'));
    await tester.tap(find.text('Again'));
    await tester.pump();
    expect(answers, [true]);
  });
}
