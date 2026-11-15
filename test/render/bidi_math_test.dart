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

/// Golden lines: the founder's 15 Nov RTL rule (SVT arrows untouched, MATH
/// interval + vectors isolated, CHEM LaTeX ion inside Arabic).
const examples = [
  'pH 8.5 ← 5 يرتفع',
  'على المجال [0;3] الدالة مستمرة',
  'AB⃗ ⊥ CD⃗ ⇒ الشعاعان متعامدان',
  r'الشاردة \(\mathrm{H_3O^+}\) تعطي الوسط الصفة الحمضية',
];

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

void main() {
  test('only vectors, ⊥ ⇒ ⇔ and intervals are isolated in Arabic', () {
    expect(isolateMathRuns('المجال [0;3] مغلق'), 'المجال $_l[0;3]$_p مغلق');
    expect(isolateMathRuns(']0;3[ مفتوح'), '$_l]0;3[$_p مفتوح');
    expect(
      isolateMathRuns('AB⃗ ⊥ CD⃗ ⇒ الشعاعان متعامدان'),
      '${_l}AB⃗ ⊥ CD⃗ ⇒$_p الشعاعان متعامدان',
    );
    // SVT arrows and equations stay in normal RTL display.
    expect(isolateMathRuns('pH 8.5 ← 5 يرتفع'), 'pH 8.5 ← 5 يرتفع');
    expect(
      isolateMathRuns('6CO2 + 12H2O → C6H12O6 + 6O2'),
      '6CO2 + 12H2O → C6H12O6 + 6O2',
    );
    // Plain numbers / Latin are not touched (content uses LaTeX for those).
    expect(isolateMathRuns('العدد -5 سالب.'), 'العدد -5 سالب.');
    expect(isolateMathRuns('لدينا i^4 = 1 دائما'), 'لدينا i^4 = 1 دائما');
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
