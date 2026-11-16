import 'package:flutter/material.dart';

import 'bare_math.dart';
import 'block_style.dart';
import 'code_block.dart';
import 'code_tokens.dart';
import 'latex_plain.dart';
import 'math_text.dart';
import 'math_view.dart';
import 'segments.dart';

/// A text with highlights (term, value, formula, warning), inline math,
/// `inline code` chips and ```fenced``` code blocks (drawn as CodeBlock).
class RichBlockText extends StatelessWidget {
  const RichBlockText({
    super.key,
    required this.text,
    required this.style,
    this.highlights = const <Object?>[],
    this.shrinkMath = false,
  });

  final String text;
  final List<Object?> highlights;
  final BlockStyle style;

  /// Narrow places (exam corrections): a formula wider than the line is
  /// scaled down instead of overflowing.
  final bool shrinkMath;

  @override
  Widget build(BuildContext context) {
    final t = wrapBareMath(normalizeLatexEscapes(text));
    final parts = splitFences(t);
    if (parts.length == 1 && !parts.first.code) return _textPart(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: parts[i].code
                ? CodeBlock(
                    code: parts[i].text,
                    language: parts[i].language,
                    style: style,
                  )
                : _textPart(parts[i].text),
          ),
      ],
    );
  }

  /// A text without fences: paragraphs plus \[ \] / $$ $$ display math.
  Widget _textPart(String text) {
    final chunks = splitDisplayMath(text);
    if (chunks.length == 1 && !chunks.first.display) return _rich(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < chunks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: chunks[i].display
                ? MathDisplay(latex: chunks[i].text, style: style.body)
                : _rich(chunks[i].text),
          ),
      ],
    );
  }

  Widget _rich(String text) {
    final base = style.body;
    return Text.rich(
      TextSpan(
        style: base,
        children: buildMathSpans(
          segmentText(text, highlights),
          base: base,
          kc: style.kc,
          rtl: style.rtl,
          shrinkMath: shrinkMath,
        ),
      ),
    );
  }
}
