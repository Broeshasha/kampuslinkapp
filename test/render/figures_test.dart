import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/lessons/figures.dart';
import 'package:kampuslink/features/home/flash_card.dart';
import 'package:kampuslink/features/home/quick_question_card.dart';
import 'package:kampuslink/render/compact_figure.dart';
import 'package:kampuslink/render/figure_block.dart';

import '../helpers/pump_in_app.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80">'
    '<rect x="4" y="4" width="112" height="72" rx="8" fill="none" '
    'stroke="{{fg}}" stroke-width="3"/>'
    '<circle cx="40" cy="40" r="18" fill="{{c1}}"/>'
    '<path d="M70 60 L100 20" stroke="{{c3}}" stroke-width="5"/></svg>';

Map<String, dynamic> _fig([String svg = _svg]) => {
  'asset': {
    'type': 'svg',
    'svg': svg,
    'alt': {'en': 'A circle in a box', 'fr': 'Un cercle dans un cadre'},
  },
  'caption': {'en': 'Circle', 'fr': 'Cercle'},
};

String? _svgOf(Map<String, dynamic>? f) {
  final asset = f?['asset'];
  return asset is Map ? asset['svg'] as String? : null;
}

const _arOptions = [
  '\u0627\u0644\u0623\u0648\u0644',
  '\u0627\u0644\u062b\u0627\u0646\u064a',
  '\u0627\u0644\u062b\u0627\u0644\u062b',
  '\u0627\u0644\u0631\u0627\u0628\u0639',
];

Future<void> _phone(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// A few frames (the SVG parse is synchronous in tests; no settle because
/// a shimmer may still be running).
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _question(String lang) => QuickQuestionCard(
  prompt: lang == 'ar'
      ? '\u0623\u064a \u0634\u0643\u0644\u061f'
      : 'Quel sch\u00e9ma ?',
  options: lang == 'ar' ? _arOptions : const ['A', 'B', 'C', 'D'],
  correctIndex: 1,
  explanation: '',
  language: lang,
  moduleName: 'Chimie',
  accent: Colors.teal,
  onAnswered: (_) {},
  figure: _fig(),
  optionFigures: [_fig(), _fig(), _fig(), _fig()],
);

void main() {
  test('the language figure wins; bare svg and option lists are read', () {
    final shared = _fig();
    final local = {'figure': _fig('<svg viewBox="0 0 1 1"></svg>')};
    expect(
      _svgOf(pickFigure(text: local, shared: shared)),
      '<svg viewBox="0 0 1 1"></svg>',
    );
    expect(pickFigure(text: const {}, shared: shared), equals(shared));
    expect(_svgOf(figureMap({'svg': _svg})), _svg);
    expect(figureMap('nope'), isNull);
    expect(pickOptionFigures(shared: [null, null], count: 2), isEmpty);
    final opts = pickOptionFigures(shared: [_fig()], count: 3);
    expect(opts.length, 3);
    expect(opts[1], isNull);
    expect(figureText({'en': 'Circle', 'fr': 'Cercle'}, 'ar'), 'Cercle');
    expect(figureText('Plain', 'ar'), 'Plain');
  });

  testWidgets('an unsafe svg becomes a small "diagram unavailable" chip', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      CompactFigure(
        figure: _fig('<svg viewBox="0 0 9 9"><script>x()</script></svg>'),
        language: 'en',
      ),
    );
    expect(find.text('Diagram unavailable'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('tap on a figure opens the zoom page', (tester) async {
    await pumpInApp(
      tester,
      Center(
        child: CompactFigure(figure: _fig(), language: 'en', height: 120),
      ),
    );
    await _frames(tester);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Circle'), findsOneWidget);
    await tester.tap(find.byType(SvgPicture));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FigureZoomPage), findsOneWidget);
  });

  for (final (size, lang, cols) in [
    (const Size(320, 568), 'fr', 1),
    (const Size(412, 915), 'ar', 2),
    (const Size(320, 568), 'ar', 1),
    (const Size(412, 915), 'fr', 2),
  ]) {
    testWidgets(
      'quick question with option figures: ${size.width.toInt()} wide, $lang, 1.5x text',
      (tester) async {
        await _phone(tester, size);
        await pumpInApp(tester, _question(lang), locale: Locale(lang));
        await _frames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(SvgPicture), findsNWidgets(5));
        final a = tester.getRect(find.byKey(const ValueKey('option-0')));
        final b = tester.getRect(find.byKey(const ValueKey('option-1')));
        if (cols == 1) {
          expect(a.left, closeTo(b.left, 0.5));
          expect(b.top, greaterThan(a.bottom - 0.5));
        } else {
          expect(a.top, closeTo(b.top, 0.5));
        }
      },
    );
  }

  testWidgets('flash card with a figure fits 320 wide at 1.5x in Arabic', (
    tester,
  ) async {
    await _phone(tester, const Size(320, 568));
    await pumpInApp(
      tester,
      FlashCardView(
        front: '\u0645\u0627 \u0647\u0630\u0627\u061f',
        back: '\u062f\u0627\u0626\u0631\u0629',
        language: 'ar',
        moduleName: 'Chimie',
        accent: Colors.teal,
        onAnswer: (_) {},
        onReport: () {},
        figure: _fig(),
      ),
      locale: const Locale('ar'),
    );
    await _frames(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('golden: flash card with a figure (fr, 320, 1.5x)', (
    tester,
  ) async {
    await _phone(tester, const Size(320, 568));
    await pumpInApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: FlashCardView(
          front: 'Que montre ce sch\u00e9ma ?',
          back: 'Un cercle',
          language: 'fr',
          moduleName: 'Chimie',
          accent: Colors.teal,
          onAnswer: (_) {},
          onReport: () {},
          figure: _fig(),
        ),
      ),
      locale: const Locale('fr'),
    );
    await _frames(tester);
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/figure_flash_card_fr_320.png'),
    );
  });

  testWidgets('golden: question with option figures (ar, 412, 1.5x)', (
    tester,
  ) async {
    await _phone(tester, const Size(412, 915));
    await pumpInApp(
      tester,
      RepaintBoundary(key: const ValueKey('golden'), child: _question('ar')),
      locale: const Locale('ar'),
    );
    await _frames(tester);
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/figure_options_ar_412.png'),
    );
  });
}
