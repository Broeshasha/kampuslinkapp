import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/math_text.dart';

/// Goldens for the shared MathText (a flash card face) and a lesson block,
/// light and dark. First run: flutter test --update-goldens on this file.
const _lessonBlocks = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'type': 'paragraph',
    'content':
        r'On pose \(x = 2\pi\) et \(\lim_{n\to+\infty} u_n = \dfrac{1}{2}\). '
        r'Ainsi \[g = 9{,}81\ \mathrm{m\,s^{-2}}\]',
  },
  {
    'id': 'e1',
    'type': 'equation',
    'latex': r'\vec{F} = m\,\vec{a}',
    'plain_text': 'F = m a',
    'display': true,
  },
];

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(
            r'Why invent \(i\)? The algebraic form',
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          MathText(
            r'Si \(z = a + ib\), alors \(|z| = \sqrt{a^2 + b^2}\).',
            style: TextStyle(fontSize: 16, color: kc.textPrimary),
          ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: RepaintBoundary(key: const ValueKey('golden'), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('golden: math card $name', (tester) async {
      await _pump(tester, theme, const Center(child: _Card()));
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/math_card_$name.png'),
      );
    });

    testWidgets('golden: math lesson block $name', (tester) async {
      await _pump(
        tester,
        theme,
        const LessonView(blocks: _lessonBlocks, language: 'fr'),
      );
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/math_lesson_$name.png'),
      );
    });
  }
}
