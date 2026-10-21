import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/cases/case_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/features/cases/case_models.dart';
import 'package:kampuslink/features/cases/case_set_view.dart';
import 'package:kampuslink/features/cases/demo_cases.dart';

import '../helpers/pump_in_app.dart';

void main() {
  test('demo sets parse in all 3 languages with one commit slide', () {
    for (final source in demoCases) {
      for (final lang in ['fr', 'ar', 'en']) {
        final set = CaseSet.fromSource(source, lang);
        expect(set.slides.length, inInclusiveRange(3, 8));
        expect(set.title, isNotEmpty);
        expect(set.commitIndex, greaterThan(0));
        expect(set.commitSlide!.options, isNotEmpty);
      }
    }
  });

  test('progress is saved and read back on the phone', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CaseRepository(db);
    expect((await repo.get('x')).started, isFalse);
    await repo.save(
      const CaseProgress(setId: 'x', reached: 3, guess: 1, answers: {'s6': 0}),
    );
    final p = await repo.get('x');
    expect(p.reached, 3);
    expect(p.guess, 1);
    expect(p.answers, {'s6': 0});
    expect((await repo.all()).keys, ['x']);
  });

  testWidgets('swipe through a case; the reveal waits for a locked guess', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final set = CaseSet.fromSource(demoCases.last, 'en');
    final saved = <CaseProgress>[];
    await pumpInApp(
      tester,
      CaseSetView(
        set: set,
        progress: CaseProgress(setId: set.id),
        onProgress: saved.add,
      ),
    );
    final pager = find.byType(PageView);
    expect(find.text('1/${set.slides.length}'), findsOneWidget);
    await tester.drag(pager, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/${set.slides.length}'), findsOneWidget);
    await tester.drag(pager, const Offset(-350, 0));
    await tester.pumpAndSettle();
    final commitPage = '${set.commitIndex + 1}/${set.slides.length}';
    expect(find.text(commitPage), findsOneWidget);
    // Try to skip the guess: the pager comes back.
    await tester.drag(pager, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text(commitPage), findsOneWidget);
    expect(find.text('Lock a guess before you see the answer'), findsOneWidget);
    // Choose the right answer and lock it: the reveal says so.
    final right = set.commitSlide!.options[set.commitSlide!.correctIndex!];
    await tester.tap(find.text(right));
    await tester.pump();
    await tester.tap(find.text('Lock my guess'));
    await tester.pumpAndSettle();
    expect(find.text('You guessed right!'), findsOneWidget);
    expect(saved.last.guess, set.commitSlide!.correctIndex);
    expect(saved.last.reached, set.commitIndex + 1);
  });
}
