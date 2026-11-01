import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'block_style.dart';
import 'code_block.dart';
import 'code_tokens.dart';
import 'latex_plain.dart';
import 'math_view.dart';
import 'segments.dart';

/// Inline formulas longer than this (source chars) scroll sideways.
const _longInline = 60;

/// In one-line places (titles, list tiles) a formula longer than this is
/// shown as readable plain text instead of being drawn.
const _compactPlainAbove = 40;

/// Spans for a segmented text: highlights, inline math (LTR islands),
/// `inline code`. Shared by [MathText] and RichBlockText.
List<InlineSpan> buildMathSpans(
  List<TextSegment> segments, {
  required TextStyle base,
  required KampusColors kc,
  required bool rtl,
  bool shrinkMath = false,
  bool compact = false,
}) {
  String ltr(String t) => rtl ? '\u2066$t\u2069' : t;
  final iconSize = base.fontSize ?? 16;
  final spans = <InlineSpan>[];
  for (final s in segments) {
    switch (s.kind) {
      case SegmentKind.plain:
        spans.add(TextSpan(text: fixBareCommands(s.text)));
      case SegmentKind.term:
        spans.add(
          TextSpan(
            text: s.text,
            style: TextStyle(color: kc.accentText, fontWeight: FontWeight.w600),
          ),
        );
      case SegmentKind.value:
        spans.add(
          TextSpan(
            text: ltr(s.text),
            style: TextStyle(color: kc.xp, fontWeight: FontWeight.w700),
          ),
        );
      case SegmentKind.formula:
        spans.add(
          TextSpan(
            text: ltr(s.text),
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
            text: ltr(s.text),
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
        spans.add(_mathSpan(s.text, base, ltr, shrinkMath, compact));
    }
  }
  return spans;
}

InlineSpan _mathSpan(
  String latex,
  TextStyle base,
  String Function(String) ltr,
  bool shrinkMath,
  bool compact,
) {
  final src = normalizeLatexEscapes(latex);
  if (compact) {
    if (src.length > _compactPlainAbove) {
      return TextSpan(text: ltr(mathToPlain(src)));
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: InlineMath(latex: src, style: base),
      ),
    );
  }
  if (shrinkMath) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: InlineMath(latex: src, style: base),
      ),
    );
  }
  if (src.length > _longInline) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: InlineMath(latex: src, style: base),
      ),
    );
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: InlineMath(latex: src, style: base),
  );
}

/// THE widget for any text that comes from content (titles, cards,
/// questions, captions, lists...). Draws \( \) / $ $ inline math, \[ \] /
/// $$ $$ display math, `inline code` and ```fences```. Math stays an LTR
/// island inside Arabic text. A formula that cannot be drawn shows as
/// small plain text (logged), never a red error.
///
/// With [maxLines] (titles, list tiles) everything stays on the given lines:
/// short formulas are drawn small, long ones become plain text, and the
/// text ends with an ellipsis.
///
/// A string without any math or code is drawn as a plain [Text], so it
/// costs nothing to use MathText everywhere.
class MathText extends StatelessWidget {
  const MathText(
    this.text, {
    super.key,
    this.style,
    this.highlights = const <Object?>[],
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.blockStyle,
    this.shrinkMath = false,
  });

  final String text;
  final TextStyle? style;
  final List<Object?> highlights;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;

  /// Lesson style: when given, ```fences``` are drawn with CodeBlock.
  final BlockStyle? blockStyle;

  /// Narrow places: formulas wider than the line are scaled down.
  final bool shrinkMath;

  bool get _compact => maxLines != null;

  TextOverflow? get _overflow =>
      overflow ?? (_compact ? TextOverflow.ellipsis : null);

  @override
  Widget build(BuildContext context) {
    final t = normalizeLatexEscapes(text);
    if (!mayContainMath(t) && highlights.isEmpty) {
      return Text(
        t,
        style: style,
        maxLines: maxLines,
        overflow: _overflow,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
      );
    }
    final base = DefaultTextStyle.of(context).style.merge(style);
    final rtl =
        (textDirection ?? Directionality.maybeOf(context)) == TextDirection.rtl;
    final kc = context.kc;
    final Widget body = _compact
        ? _line(latexFreeFences(t), base, kc, rtl)
        : _blocks(context, t, base, kc, rtl);
    if (!t.contains(r'\') && !t.contains(r'$')) return body;
    return Semantics(
      label: latexToPlain(t),
      excludeSemantics: true,
      child: body,
    );
  }

  Widget _line(String t, TextStyle base, KampusColors kc, bool rtl) {
    return Text.rich(
      TextSpan(
        style: style,
        children: buildMathSpans(
          segmentText(t, highlights),
          base: base,
          kc: kc,
          rtl: rtl,
          compact: true,
        ),
      ),
      maxLines: maxLines,
      overflow: _overflow,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
    );
  }

  Widget _paragraph(String t, TextStyle base, KampusColors kc, bool rtl) {
    return Text.rich(
      TextSpan(
        style: style,
        children: buildMathSpans(
          segmentText(t, highlights),
          base: base,
          kc: kc,
          rtl: rtl,
          shrinkMath: shrinkMath,
        ),
      ),
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
    );
  }

  Widget _blocks(
    BuildContext context,
    String t,
    TextStyle base,
    KampusColors kc,
    bool rtl,
  ) {
    final children = <Widget>[];
    for (final part in splitFences(t)) {
      if (part.code) {
        final bs = blockStyle;
        children.add(
          bs != null
              ? CodeBlock(code: part.text, language: part.language, style: bs)
              : _PlainCode(code: part.text, base: base, kc: kc),
        );
        continue;
      }
      for (final chunk in splitDisplayMath(part.text)) {
        children.add(
          chunk.display
              ? MathDisplay(latex: chunk.text, style: base)
              : _paragraph(chunk.text, base, kc, rtl),
        );
      }
    }
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: children[i],
          ),
      ],
    );
  }
}

/// One-line places: code fences become their code text, display math
/// becomes inline math.
String latexFreeFences(String t) {
  if (!t.contains('```') && !t.contains(r'\[') && !t.contains(r'$$')) return t;
  final b = StringBuffer();
  for (final part in splitFences(t)) {
    if (b.isNotEmpty) b.write(' ');
    b.write(part.code ? '`${part.text.replaceAll('\n', ' ')}`' : part.text);
  }
  return b.toString().replaceAll('\n', ' ');
}

class _PlainCode extends StatelessWidget {
  const _PlainCode({required this.code, required this.base, required this.kc});

  final String code;
  final TextStyle base;
  final KampusColors kc;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kc.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            code,
            style: base.copyWith(
              fontFamily: codeFontFamily,
              fontFamilyFallback: codeFontFallback,
              fontSize: (base.fontSize ?? 16) * 0.9,
            ),
          ),
        ),
      ),
    );
  }
}
