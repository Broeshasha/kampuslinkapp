import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:kampuslink/render/bidi_math.dart';
import 'package:kampuslink/render/block_style.dart';
import 'package:kampuslink/render/rich_block_text.dart';

const _l = '\u2066';
const _p = '\u2069';

/// The 4 examples from the bac maths content review.
const examples = [
  'العدد -5 سالب.',
  'المجال [0;3] مغلق',
  'لدينا i^4 = 1 دائما',
  'AB⃗ ⊥ CD⃗ ⇒ الشعاعان متعامدان',
];

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

void main() {
  test('maths runs inside Arabic stay left-to-right', () {
    expect(isolateMathRuns(examples[0]), 'العدد $_l-5$_p سالب.');
    expect(isolateMathRuns(examples[1]), 'المجال $_l[0;3]$_p مغلق');
    expect(isolateMathRuns(examples[2]), 'لدينا ${_l}i^4 = 1$_p دائما');
    expect(
      isolateMathRuns(examples[3]),
      '${_l}AB⃗ ⊥ CD⃗ ⇒$_p الشعاعان متعامدان',
    );
    expect(isolateMathRuns(']0;3[ مفتوح'), '$_l]0;3[$_p مفتوح');
    expect(isolateMathRuns('نص عربي فقط'), 'نص عربي فقط');
  });

  test('vector letters use the maths font', () {
    final spans = plainTextSpans('AB⃗ ⊥ CD⃗', rtl: false);
    final math = spans
        .whereType<TextSpan>()
        .where((s) => s.style?.fontFamily == 'NotoSansMath')
        .map((s) => s.text);
    expect(math, ['AB⃗', 'CD⃗']);
  });

  testWidgets('golden: Arabic sentences with maths (RTL)', (tester) async {
    await _loadFont('Cairo', ['assets/fonts/Cairo-Regular.ttf']);
    await _loadFont('NotoSansMath', ['assets/fonts/NotoSansMath-Regular.ttf']);
    final theme = ThemeData(
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['NotoSansMath'],
      extensions: [KampusColors.light],
    );
    await tester.binding.setSurfaceSize(const Size(420, 360));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Builder(
          builder: (context) {
            final style = BlockStyle(
              language: 'ar',
              scale: 1.2,
              kc: context.kc,
              labels: lookupAppLocalizations(const Locale('ar')),
              base: const TextStyle(fontSize: 18, color: Colors.black),
            );
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in examples)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RichBlockText(text: e, style: style),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/bidi_math_ar.png'),
    );
  });
}
