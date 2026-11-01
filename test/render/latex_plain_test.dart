import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/latex_plain.dart';

void main() {
  const cases = <(String, String)>[
    ('On pose \\(x = 2\\pi\\)', 'On pose x = 2\u03C0'),
    (
      '\\(\\lim_{n\\to+\\infty} u_n = \\dfrac{1}{2}\\)',
      'lim_(n\u2192+\u221E) u\u2099 = 1/2',
    ),
    ('\\(g = 9{,}81\\ \\mathrm{m\\,s^{-2}}\\)', 'g = 9,81 m s\u207B\u00B2'),
    ('\\(x^2 + y^2\\)', 'x\u00B2 + y\u00B2'),
    ('\\(\\frac{a+b}{c}\\)', '(a+b)/c'),
    ('\\(\\sqrt{x}\\)', '\u221Ax'),
    ('\\(\\sqrt{x+1}\\)', '\u221A(x+1)'),
    ('\\(\\sqrt[3]{8}\\)', '\u221B8'),
    ('\\(a \\leq b \\geq c\\)', 'a \u2264 b \u2265 c'),
    ('\\(\\omega = 2\\pi f\\)', '\u03C9 = 2\u03C0 f'),
    ('\\(\\vec{v}\\)', 'v\u20D7'),
    ('\\(\\overrightarrow{AB}\\)', 'AB\u20D7'),
    ('\\(\\dot{x}\\)', 'x\u0307'),
    ('\\(\\sum_{i=1}^{n} x_i\\)', '\u2211\u1D62\u208C\u2081\u207F x\u1D62'),
    ('\\(\\int_0^1 f\\)', '\u222B\u2080\u00B9 f'),
    ('\\(\\Delta x \\sim 0\\)', '\u0394 x \u223C 0'),
    ('\\(\\text{si } x > 0\\)', 'si x > 0'),
    ('\\(\\left( a \\right)\\)', '( a )'),
    ('\\\\(\\\\frac{1}{2}\\\\)', '1/2'),
    ('Run `ls -a` now', 'Run ls -a now'),
    ('A\n```python\nprint(1)\n```', 'A\nprint(1)'),
    ('\$\\pi r^2\$', '\u03C0 r\u00B2'),
    ('\\[E = mc^2\\]', 'E = mc\u00B2'),
    ('Voir \\(x + 1', 'Voir x + 1'),
    (
      '\u0627\u0644\u0633\u0631\u0639\u0629 \\(v = 3\\) \u0645',
      '\u0627\u0644\u0633\u0631\u0639\u0629 v = 3 \u0645',
    ),
    ('H\u2082O', 'H\u2082O'),
    ('\\(T = 20^{\\circ}\\mathrm{C}\\)', 'T = 20\u00B0C'),
    ('\\forall x', '\u2200 x'),
    ('\\(\\mathbb{R}\\)', '\u211D'),
    ('\\(10^{23}\\)', '10\u00B2\u00B3'),
    ('\\(N_A\\)', 'N_A'),
    ('\\(u_{n+1}\\)', 'u\u2099\u208A\u2081'),
    ('\\(x \\to \\infty\\)', 'x \u2192 \u221E'),
    ('Prix 5 \$ et 6 \$', 'Prix 5 \$ et 6 \$'),
    ('\\(\\vec{F} = m\\vec{a}\\)', 'F\u20D7 = ma\u20D7'),
    ('\\(e^{i\\theta}\\)', 'e^(i\u03B8)'),
    ('\\(\\Delta E = \\frac{1}{2} m v^2\\)', '\u0394 E = 1/2 m v\u00B2'),
  ];

  for (final (input, want) in cases) {
    test('latexToPlain: $input', () => expect(latexToPlain(input), want));
  }

  test('fixBareCommands keeps prose, swaps known symbols', () {
    expect(
      fixBareCommands(
        'Negation swaps \\forall and \\exists, cost \\\$5, see C:\\Users',
      ),
      'Negation swaps \u2200 and \u2203, cost \$5, see C:\\Users',
    );
  });

  test('double escaping is undone once; a real line break stays', () {
    expect(normalizeLatexEscapes('\\\\frac{1}{2}'), '\\frac{1}{2}');
    expect(normalizeLatexEscapes('a \\\\ b'), 'a \\\\ b');
  });

  test('splitMath: inline, display, dollar; code is skipped', () {
    final kinds = splitMath('a \\(x\\) b \\[y\\] c \$z\$ `\$q\$`')
        .map((p) => '${p.kind.name}:${p.text}')
        .toList();
    expect(kinds, [
      'text:a ',
      'inline:x',
      'text: b ',
      'display:y',
      'text: c ',
      'inline:z',
      'text: `\$q\$`',
    ]);
  });

  test('unclosed \\( runs to the end, stray \\) is dropped', () {
    expect(splitMath('Voir \\(x + 1').last.kind, MathPieceKind.inline);
    expect(latexToPlain('fin \\) ici'), 'fin ici');
  });

  test('looksLikeLatex', () {
    expect(looksLikeLatex('\\omega t'), isTrue);
    expect(looksLikeLatex('x_{1}'), isTrue);
    expect(looksLikeLatex('Force F'), isFalse);
  });
}
