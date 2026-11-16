import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/bare_math.dart';

void main() {
  test('bare powers become inline math', () {
    expect(wrapBareMath('ratio e^{−4}'), r'ratio \(e^{-4}\)');
    expect(wrapBareMath('10^-pH = 2,0×10^-4 mol/L'), r'\(10^{-pH}\) = 2,0×\(10^{-4}\) mol/L');
    expect(wrapBareMath('i(t) = a(1 - e^(-t/τ))'), r'i(t) = a(1 - \(e^{-t/\tau }\))');
    expect(wrapBareMath('x^2 + y^2 = 1'), r'\(x^{2}\) + \(y^{2}\) = 1');
  });

  test('Arabic around, functions, indices', () {
    expect(
      wrapBareMath('حسابية أساسها e^{−4}'),
      r'حسابية أساسها \(e^{-4}\)',
    );
    expect(wrapBareMath('(z₁/z₂)^2008 عدد حقيقي'), r'\((z_{1}/z_{2})^{2008}\) عدد حقيقي');
    expect(wrapBareMath('a^b = e^{b ln a}'), r'\(a^{b}\) = \(e^{b \ln a}\)');
    expect(wrapBareMath('g(b) − g(a) = ∫_a^b f(x)dx'), r'g(b) − g(a) = \(\int _a^{b}\) f(x)dx');
  });

  test('left alone: delimited math, code, nothing to do, raw LaTeX with Arabic', () {
    expect(wrapBareMath(r'déjà \(x^2\) ok'), r'déjà \(x^2\) ok');
    expect(wrapBareMath('no math here'), 'no math here');
    expect(wrapBareMath('`a^b` code'), '`a^b` code');
    expect(wrapBareMath('price 5^ ok'), 'price 5^ ok');
  });

  test('raw LaTeX without delimiters becomes one formula', () {
    expect(wrapBareMath(r'N(t) = N_0\, e^{-\lambda t}'), r'\(N(t) = N_0\, e^{-\lambda t}\)');
  });
}
