import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/math_text.dart';
import 'package:kampuslink/render/math_view.dart';

import '../helpers/pump_in_app.dart';

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _ltrInside(Finder math) => find.descendant(
  of: math,
  matching: find.byWidgetPredicate(
    (w) => w is Directionality && w.textDirection == TextDirection.ltr,
  ),
);

void main() {
  testWidgets('plain text stays a plain Text (no cost)', (tester) async {
    await pumpInApp(tester, const MathText('Composition and inverse map'));
    expect(find.text('Composition and inverse map'), findsOneWidget);
    expect(find.byType(InlineMath), findsNothing);
  });

  testWidgets('fr: inline math is drawn, no raw delimiters', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const MathText(
        r'On pose \(x = 2\pi\) et \(g = 9{,}81\ \mathrm{m\,s^{-2}}\).',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InlineMath), findsNWidgets(2));
    expect(find.byKey(const ValueKey('math-fallback')), findsNothing);
  });

  testWidgets('ar RTL: math is an LTR island', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const Directionality(
        textDirection: TextDirection.rtl,
        child: MathText(
          '\u0627\u0644\u0633\u0631\u0639\u0629 '
          r'\(v = \dfrac{d}{t}\)'
          ' \u0628\u0627\u0644\u0645\u062A\u0631.',
        ),
      ),
      locale: const Locale('ar'),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InlineMath), findsOneWidget);
    expect(_ltrInside(find.byType(InlineMath)), findsOneWidget);
  });

  testWidgets('display math \\[ \\] gets its own centred line', (tester) async {
    await _phone(tester);
    await pumpInApp(tester, const MathText(r'Formule : \[E = mc^2\] et fin.'));
    expect(tester.takeException(), isNull);
    expect(find.byType(MathDisplay), findsOneWidget);
  });

  testWidgets('a very long formula scrolls, never overflows', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const MathText(
        r'Soit \(\lim_{n\to+\infty} \left(1 + \dfrac{1}{n}\right)^{n} + \sum_{k=0}^{n} \dfrac{x^k}{k!} + \int_0^1 e^{-t^2}\,dt\) ici.',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('a broken formula shows plain text, never a red error', (
    tester,
  ) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const MathText(
        'Cas '
        r'\(\frac{1}{\)'
        ' cass\u00E9.',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('math-fallback')), findsOneWidget);
  });

  testWidgets('double-escaped strings are fixed once', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const MathText(
        'Moiti\u00E9 '
        r'\\(\\frac{1}{2}\\)',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InlineMath), findsOneWidget);
    expect(find.byKey(const ValueKey('math-fallback')), findsNothing);
  });

  testWidgets('code fence is drawn as code', (tester) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const MathText('Voici :\n```python\nprint(1)\n```\nFin.'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('print(1)'), findsOneWidget);
  });

  testWidgets('one-line title: math drawn small, ellipsis, no overflow', (
    tester,
  ) async {
    await _phone(tester);
    await pumpInApp(
      tester,
      const SizedBox(
        width: 200,
        child: MathText(
          r'Why invent \(i\)? The algebraic form of a complex number',
          maxLines: 1,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.maxLines == 1 &&
            w.overflow == TextOverflow.ellipsis,
      ),
      findsOneWidget,
    );
  });
}
