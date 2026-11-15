import 'package:flutter/painting.dart';

/// Content review (bac, Arabic), founder rule of 15 Nov 2026:
/// - LaTeX \( ... \) is drawn as a formula widget: always left-to-right.
/// - Plain text is NOT isolated by default (SVT writes "8.5 ← 5" and
///   equations with → that are right only in normal RTL display).
/// - Exceptions, isolated left-to-right with LRI U+2066 ... PDI U+2069:
///   a run with a vector mark (U+20D0-U+20FF, e.g. "AB⃗"), with ⊥ ⇒ ⇔, or an
///   interval like "[0;3]" / "]0;3[". Never a run that contains ← or →.
/// Plain "-5" or "i^4 = 1" stay as typed: content writes them as LaTeX.
const _lri = '\u2066';
const _pdi = '\u2069';

const _tok =
    r"[-−+]?[\[\]\(\{|]?[0-9A-Za-z][0-9A-Za-z̀-ͯ⃐-⃿\^.,;:\[\]\(\)\{\}'_|]*";
const _op = r'[=+\-−×÷<>≤≥≠±*/⊥⇒⇔→←∈∉⊂⊃∩∪≈∥]';

final _mathRun = RegExp('$_tok(?:\\s*$_op+\\s*$_tok)*(?:\\s*[⊥⇒⇔→])?');
final _vector = RegExp('[\u20D0-\u20FF]');
final _logic = RegExp('[⊥⇒⇔]');
final _arrow = RegExp('[←→]');
final _interval = RegExp(r'^[\[\]]\s*[-−+]?[0-9A-Za-z.,∞]+\s*;\s*[-−+]?[0-9A-Za-z.,∞]+\s*[\[\]]$');

/// Only these plain runs are isolated (see the rule above).
bool _isolate(String run) =>
    !_arrow.hasMatch(run) &&
    (_vector.hasMatch(run) || _logic.hasMatch(run) || _interval.hasMatch(run));
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
  if (run.isEmpty || !_isolate(run)) return m[0]!;
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
