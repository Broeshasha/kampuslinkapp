import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/lesson_view.dart';

import '../helpers/pump_in_app.dart';

List<Map<String, dynamic>> blocks(String lang) => [
  for (var i = 0; i < 40; i++)
    {'id': 'p$i', 'type': 'paragraph', 'content': '$lang paragraph $i. ' * 12},
];

void main() {
  testWidgets('opens at the saved block, and keeps it when the language '
      'or the text size changes', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<LessonViewState>();
    String? reported;
    Future<void> show(String lang, double scale) async {
      await pumpInApp(
        tester,
        LessonView(
          key: key,
          blocks: blocks(lang),
          language: lang,
          scale: scale,
          initialBlockId: 'p20',
          onPosition: (id, progress) => reported = id,
        ),
      );
      await tester.pumpAndSettle();
    }

    await show('fr', 1);
    expect(key.currentState!.currentBlockId, 'p20');
    expect(reported, 'p20');
    await show('ar', 1);
    expect(key.currentState!.currentBlockId, 'p20');
    await show('ar', 1.2);
    expect(key.currentState!.currentBlockId, 'p20');
  });

  testWidgets('scrolling reports the first visible block', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? reported;
    double? progress;
    await pumpInApp(
      tester,
      LessonView(
        blocks: blocks('en'),
        language: 'en',
        onPosition: (id, p) {
          reported = id;
          progress = p;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(reported, isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(reported, isNot('p0'));
    expect(progress, greaterThan(0));
    expect(progress, lessThan(1));
  });
}
