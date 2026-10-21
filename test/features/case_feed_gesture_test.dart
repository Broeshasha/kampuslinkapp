import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/cases/case_models.dart';
import 'package:kampuslink/features/cases/case_set_view.dart';
import 'package:kampuslink/features/cases/demo_cases.dart';

import '../helpers/pump_in_app.dart';

void main() {
  Future<void> pumpFeed(
    WidgetTester tester,
    String lang, {
    bool hint = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final set = CaseSet.fromSource(demoCases.first, lang);
    await pumpInApp(
      tester,
      PageView(
        scrollDirection: Axis.vertical,
        children: [
          CaseSetView(
            set: set,
            progress: CaseProgress(setId: set.id),
            onProgress: (_) {},
            showSwipeHint: hint,
          ),
          const Center(child: Text('next post')),
        ],
      ),
      locale: Locale(lang),
    );
  }

  testWidgets('horizontal drags move the slides, vertical drags the feed', (
    tester,
  ) async {
    await pumpFeed(tester, 'en', hint: true);
    final count = CaseSet.fromSource(demoCases.first, 'en').slides.length;
    expect(find.text('1/$count'), findsOneWidget);
    expect(find.text('Swipe to see more'), findsOneWidget);
    // A horizontal drag stays inside the carousel.
    await tester.drag(find.byType(PageView).last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/$count'), findsOneWidget);
    expect(find.text('next post'), findsNothing);
    expect(find.text('Swipe to see more'), findsNothing);
    // A vertical drag goes to the next post.
    await tester.drag(find.byType(PageView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('next post'), findsOneWidget);
  });

  testWidgets('in Arabic the carousel swipes the other way', (tester) async {
    await pumpFeed(tester, 'ar');
    final count = CaseSet.fromSource(demoCases.first, 'ar').slides.length;
    await tester.drag(find.byType(PageView).last, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/$count'), findsOneWidget);
  });
}
