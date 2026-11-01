import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/math_view.dart';

import '../helpers/pump_in_app.dart';

void main() {
  testWidgets('heading and figure caption draw their math', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpInApp(
      tester,
      const LessonView(
        language: 'en',
        blocks: <Map<String, dynamic>>[
          {
            'id': 'h1',
            'type': 'heading',
            'level': 2,
            'content': r'Why invent \(i\)?',
          },
          {
            'id': 'f1',
            'type': 'figure',
            'caption': r'Negation swaps \(\forall\) and \(\exists\)',
            'asset': {
              'type': 'svg',
              'svg':
                  "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 40'>"
                  r"<text x='5' y='20'>\(\forall x\)</text></svg>",
            },
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(InlineMath), findsNWidgets(3));
    expect(find.textContaining(r'\('), findsNothing);
  });
}
