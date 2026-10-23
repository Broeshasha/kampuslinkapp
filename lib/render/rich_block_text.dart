import 'package:flutter/material.dart';

import 'block_style.dart';
import 'code_block.dart';
import 'code_tokens.dart';
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
  });

  final String text;
  final List<Object?> highlights;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final parts = splitFences(text);
    if (parts.length == 1 && !parts.first.code) return _rich(text);
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
                : _rich(parts[i].text),
          ),
      ],
    );
  }

  Widget _rich(String text) {
    final kc = style.kc;
    final base = style.body;
    final iconSize = base.fontSize ?? 16;
    final spans = <InlineSpan>[];
    for (final s in segmentText(text, highlights)) {
      switch (s.kind) {
        case SegmentKind.plain:
          spans.add(TextSpan(text: s.text));
        case SegmentKind.term:
          spans.add(
            TextSpan(
              text: s.text,
              style: TextStyle(
                color: kc.accentText,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        case SegmentKind.value:
          spans.add(
            TextSpan(
              text: style.ltr(s.text),
              style: TextStyle(color: kc.xp, fontWeight: FontWeight.w700),
            ),
          );
        case SegmentKind.formula:
          spans.add(
            TextSpan(
              text: style.ltr(s.text),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                backgroundColor: kc.surfaceRaised,
              ),
            ),
          );
        case SegmentKind.warning:
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.warning_amber_rounded,
                size: iconSize,
                color: kc.warning,
              ),
            ),
          );
          spans.add(
            TextSpan(
              text: ' ${s.text}',
              style: TextStyle(color: kc.warning, fontWeight: FontWeight.w700),
            ),
          );
        case SegmentKind.code:
          spans.add(
            TextSpan(
              text: style.ltr(s.text),
              style: TextStyle(
                fontFamily: codeFontFamily,
                fontFamilyFallback: codeFontFallback,
                fontSize: (base.fontSize ?? 16) * 0.92,
                color: kc.accentText,
                backgroundColor: kc.surfaceRaised,
              ),
            ),
          );
        case SegmentKind.math:
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InlineMath(latex: s.text, style: base),
            ),
          );
      }
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
