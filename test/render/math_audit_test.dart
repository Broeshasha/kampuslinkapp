import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/latex_plain.dart';
import 'package:kampuslink/render/math_audit.dart';

void main() {
  test('audit finds parse errors, unclosed delimiters and bare LaTeX', () {
    final issues = auditJson(
      {
        'fr': {
          'title': r'Why invent \(i\)?',
          'blocks': [
            {'type': 'equation', 'latex': r'\frac{1}{'},
            {'content': r'Bad \(\frac{1}{\) and \(x+1'},
            {'content': r'N = n \times N_A'},
            {'content': r'Le prix: 5 $ et 6 $.'},
          ],
        },
      },
      where: 'lesson 1',
      moduleId: 3,
    );
    expect(issues.length, 4, reason: issues.map((i) => i.toLine()).join('\n'));
    expect(issues.first.path, 'fr.blocks[0].latex');
    expect(issues.first.moduleId, 3);
    expect(issues.where((i) => i.error.startsWith('unclosed')).length, 1);
    expect(issues.last.error, startsWith('LaTeX outside'));
    expect(issues.first.toLine(), startsWith('module 3 | lesson 1 |'));
  });

  test('good content gives no issue', () {
    expect(
      auditJson({
        'a': r'On pose \(x = 2\pi\) et \(g = 9{,}81\ \mathrm{m\,s^{-2}}\).',
        'latex': r'\vec{F} = m\,\vec{a}',
        'b': 'Plain words, H2O, snake_case and `x_1` in code.',
      }, where: 'card 1'),
      isEmpty,
    );
  });

  test('svg text: LaTeX becomes readable plain text, XML stays valid', () {
    const svg =
        "<svg viewBox='0 0 100 40'>"
        r"<text x='1'>\(\omega t\)</text>"
        "<text x='2'>Force F</text>"
        "<text x='3'>x^{2} + 1</text>"
        r"<text x='4'><tspan>\(a &lt; b\)</tspan></text>"
        '</svg>';
    final out = svgMathToPlain(svg);
    expect(out, contains("<text x='1'>\u03C9 t</text>"));
    expect(out, contains("<text x='2'>Force F</text>"));
    expect(out, contains("<text x='3'>x\u00B2 + 1</text>"));
    expect(out, contains('<tspan>a &lt; b</tspan>'));
    expect(
      svgMathToPlain("<svg viewBox='0 0 1 1'/>"),
      "<svg viewBox='0 0 1 1'/>",
    );
  });
}
