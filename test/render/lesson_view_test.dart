import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/demo_lesson.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/source_adapter.dart';

import '../helpers/pump_in_app.dart';

/// Local only (rights unknown, D-013): these tests skip when it is missing.
final fixture = File('fixtures/chapter_02_chimie_minerale.json');

Map<String, dynamic> loadFixture() =>
    (jsonDecode(fixture.readAsStringSync()) as Map).cast<String, dynamic>();

void main() {
  for (final lang in ['fr', 'ar', 'en']) {
    testWidgets('demo lesson renders every block type in $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpInApp(
        tester,
        LessonView(
          blocks: blocksFromSourceChapter(demoChapter, lang),
          language: lang,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('demo_u1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('demo_u1')), findsOneWidget);
    });
  }

  testWidgets('a broken formula shows its plain text, never red', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const LessonView(
        blocks: [
          {
            'id': 'x',
            'type': 'chemical_reaction',
            'formula': {'latex': r'\mathrm{O}_{2', 'plain_text': 'O2 broken'},
          },
        ],
        language: 'fr',
      ),
    );
    expect(find.byKey(const ValueKey('formula-fallback')), findsOneWidget);
    expect(find.text('O2 broken'), findsOneWidget);
  });

  testWidgets('unknown block types show their text and never crash', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const LessonView(
        blocks: [
          {'id': 'u', 'type': 'hologram', 'content': 'Still readable'},
        ],
        language: 'en',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Still readable'), findsOneWidget);
  });

  testWidgets('all 30 chapter-2 formulas render (no fallback)', (tester) async {
    final reactions = blocksFromSourceChapter(
      loadFixture(),
      'fr',
    ).where((b) => b['type'] == 'chemical_reaction').toList();
    expect(reactions.length, 30);
    for (final r in reactions) {
      await pumpInApp(tester, LessonView(blocks: [r], language: 'fr'));
      expect(
        find.byKey(const ValueKey('formula-fallback')),
        findsNothing,
        reason: '${r['id']}',
      );
    }
  }, skip: !fixture.existsSync());

  testWidgets('every chapter-2 block renders in fr, ar and en', (tester) async {
    final source = loadFixture();
    for (final lang in ['fr', 'ar', 'en']) {
      final blocks = blocksFromSourceChapter(source, lang);
      expect(blocks.length, greaterThan(100));
      for (final b in blocks) {
        await pumpInApp(tester, LessonView(blocks: [b], language: lang));
        expect(tester.takeException(), isNull, reason: '$lang ${b['id']}');
      }
    }
  }, skip: !fixture.existsSync());
}
