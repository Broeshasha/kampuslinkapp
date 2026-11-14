import 'package:flutter/painting.dart';

/// Content review (bac, Arabic): inside right-to-left text, plain maths like
/// "-5", "[0;3]", "i^4 = 1" or "AB⃗ ⊥ CD⃗ ⇒" must stay left-to-right. Each
/// maths run is wrapped in a Unicode isolate (LRI U+2066 ... PDI U+2069).
const _lri = '\u2066';
const _pdi = '\u2069';

const _tok =
    r"[-−+]?[\[\]\(\{|]?[0-9A-Za-z][0-9A-Za-z̀-ͯ⃐-⃿\^.,;:\[\]\(\)\{\}'_|]*";
const _op = r'[=+\-−×÷<>≤≥≠±*/⊥⇒⇔→←∈∉⊂⊃∩∪≈∥]';

final _mathRun = RegExp('$_tok(?:\\s*$_op+\\s*$_tok)*(?:\\s*[⊥⇒⇔→])?');
final _trailing = RegExp(r'[.,;:]+$');

/// [text] with every maths run isolated left-to-right. Sentence punctuation
/// right after a run stays outside the isolate.
String isolateMathRuns(String text) => text.replaceAllMapped(_mathRun, (m) {
  var run = m[0]!;
  var tail = '';
  final t = _trailing.firstMatch(run);
  if (t != null) {
    tail = run.substring(t.start);
    run = run.substring(0, t.start);
  }
  if (run.isEmpty) return m[0]!;
  return '$_lri$run$_pdi$tail';
});

/// A letter (or several) carrying a combining mark such as the vector arrow
/// U+20D7: drawn with the maths font so the arrow sits on the letter.
final _combined = RegExp(r'[0-9A-Za-z]+[⃐-⃿]+');

/// Spans for a plain text: maths runs isolated in RTL, vector letters in the
/// maths font.
List<InlineSpan> plainTextSpans(String text, {required bool rtl}) {
  final t = rtl ? isolateMathRuns(text) : text;
  if (!_combined.hasMatch(t)) return [TextSpan(text: t)];
  final out = <InlineSpan>[];
  var at = 0;
  for (final m in _combined.allMatches(t)) {
    if (m.start > at) out.add(TextSpan(text: t.substring(at, m.start)));
    out.add(
      TextSpan(
        text: m[0],
        style: const TextStyle(fontFamily: 'NotoSansMath'),
      ),
    );
    at = m.end;
  }
  if (at < t.length) out.add(TextSpan(text: t.substring(at)));
  return out;
}
