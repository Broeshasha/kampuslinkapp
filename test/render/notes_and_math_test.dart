import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/lesson_view.dart';

import '../helpers/pump_in_app.dart';

/// Statistics-style formulas the import tool will deliver (lead brief 4e).
const statsFormulas = [
  r'\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i',
  r'\overline{X} \approx \mu \pm z_{\alpha/2}\frac{\sigma}{\sqrt{n}}',
  r'P(X = k) = \binom{n}{k} p^k (1-p)^{n-k}',
  r'\int_{0}^{\infty} \lambda e^{-\lambda x}\,dx = 1',
  r'\mathbb{E}[X] = \sum_{x} x\,P(X = x)',
  r'\mathrm{Var}(X) = \mathbb{E}[X^2] - \left(\mathbb{E}[X]\right)^2',
  r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}^{-1} = \frac{1}{ad - bc}\begin{pmatrix} d & -b \\ -c & a \end{pmatrix}',
  r'\alpha, \beta, \gamma, \Delta, \Omega, \rho_{XY}, \sigma^2',
  r'P(A \mid B) = \frac{P(B \mid A)\,P(A)}{P(B)}',
  r'\lim_{n \to \infty} \left(1 + \frac{1}{n}\right)^{n} = e',
];

List<Map<String, dynamic>> formulaBlocks() => [
  for (var i = 0; i < statsFormulas.length; i++)
    {
      'id': 'eq$i',
      'type': 'equation',
      'latex': statsFormulas[i],
      'plain_text': 'formula $i',
      'number': i + 1,
    },
];

const arabicParagraph = {
  'id': 'ar1',
  'type': 'paragraph',
  'origin': 'import-tool',
  'content':
      '\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u0639\u064a\u0646\u0629 '
      r'\(\bar{x} = 12{,}5\)'
      ' \u0648\u0627\u0644\u0627\u0646\u062d\u0631\u0627\u0641 '
      r'\(\sigma = 2{,}1\)'
      ' \u0639\u0644\u0649 30 \u0637\u0627\u0644\u0628\u064b\u0627.',
  'highlights': [
    {'text': '30', 'kind': 'value'},
  ],
};

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('every statistics formula renders (no fallback)', (tester) async {
    await _phone(tester);
    for (final block in formulaBlocks()) {
      await pumpInApp(tester, LessonView(blocks: [block], language: 'fr'));
      expect(tester.takeException(), isNull, reason: '${block['latex']}');
      expect(
        find.byKey(const ValueKey('formula-fallback')),
        findsNothing,
        reason: '${block['latex']}',
      );
    }
  });

  testWidgets('note_kind gives each note its own label; unknown = Note', (
    tester,
  ) async {
    await _phone(tester);
    Map<String, dynamic> note(String id, String? kind) => {
      'id': id,
      'type': 'note',
      'content': 'text $id',
      'note_kind': ?kind,
      'origin': 'ignored',
    };
    await pumpInApp(
      tester,
      LessonView(
        blocks: [
          note('n1', 'intuition'),
          note('n2', 'mistake'),
          note('n3', 'exam_tip'),
          note('n4', 'remember'),
          note('n5', 'something_new'),
          note('n6', null),
        ],
        language: 'en',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('In plain words'), findsOneWidget);
    expect(find.text('Common mistake'), findsOneWidget);
    expect(find.text('Exam tip'), findsOneWidget);
    expect(find.text('Remember'), findsOneWidget);
    expect(find.text('Note'), findsNWidgets(2));
  });

  testWidgets('golden: statistics formulas', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: LessonView(blocks: formulaBlocks(), language: 'fr'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/stats_formulas.png'),
    );
  });

  testWidgets('golden: Arabic paragraph with inline math and numbers', (
    tester,
  ) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: const LessonView(blocks: [arabicParagraph], language: 'ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/arabic_inline_math.png'),
    );
  });
}
