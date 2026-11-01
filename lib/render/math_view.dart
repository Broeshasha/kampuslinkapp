import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/logging/logger.dart';
import '../core/theme/tokens.dart';
import 'block_style.dart';
import 'code_block.dart' show codeFontFamily, codeFontFallback;
import 'latex_plain.dart';

final _loggedMath = <String>{};

/// Logs a formula that could not be drawn (once per formula).
void logMathFailure(String latex, String why) {
  if (_loggedMath.length < 500 && _loggedMath.add(latex)) {
    appLog.warn('math failed: $latex ($why)');
  }
}

/// The parse error of [latex], or null when flutter_math can draw it.
/// Used by the Math audit; never throws.
String? latexParseError(String latex) {
  try {
    final m = Math.tex(normalizeLatexEscapes(latex));
    return m.parseError?.message;
  } catch (e) {
    return '$e';
  }
}

/// A formula that cannot be drawn: its readable plain text, small and
/// monospace, never a red error.
class MathSourceFallback extends StatelessWidget {
  const MathSourceFallback({
    super.key,
    required this.latex,
    required this.style,
  });

  final String latex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final plain = mathToPlain(latex);
    return Text(
      plain.isEmpty ? latex : plain,
      style: style.copyWith(
        fontFamily: codeFontFamily,
        fontFamilyFallback: codeFontFallback,
        fontSize: (style.fontSize ?? 16) * 0.9,
      ),
    );
  }
}

/// Display math inside a text (\[ ... \] or $$ ... $$): centred, LTR,
/// scrolls sideways when wider than the screen.
class MathDisplay extends StatelessWidget {
  const MathDisplay({super.key, required this.latex, required this.style});

  final String latex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final src = normalizeLatexEscapes(latex).trim();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: c.maxWidth.isFinite ? c.maxWidth : 0,
              ),
              child: Center(
                child: Math.tex(
                  src,
                  mathStyle: MathStyle.display,
                  textStyle: style.copyWith(
                    fontSize: (style.fontSize ?? 16) * 1.1,
                  ),
                  onErrorFallback: (error) {
                    logMathFailure(src, error.message);
                    return MathSourceFallback(
                      key: const ValueKey('math-fallback'),
                      latex: src,
                      style: style,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline \( ... \) math on the text baseline; raw text if it cannot parse.
class InlineMath extends StatelessWidget {
  const InlineMath({super.key, required this.latex, required this.style});

  final String latex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final src = normalizeLatexEscapes(latex);
    if (src.trim().isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        src,
        mathStyle: MathStyle.text,
        textStyle: style,
        onErrorFallback: (error) {
          logMathFailure(src, error.message);
          return MathSourceFallback(
            key: const ValueKey('math-fallback'),
            latex: src,
            style: style,
          );
        },
      ),
    );
  }
}

/// Shown when a formula cannot be drawn: its plain text, never a red error.
class FormulaFallback extends StatelessWidget {
  const FormulaFallback({super.key, required this.text, required this.style});

  final String text;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: style.kc.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: style.body.copyWith(fontSize: 16 * style.scale)),
    );
  }
}

/// Display math (chemical_reaction, equation): centred, scrolls sideways
/// when long, optional equation number, plain-text fallback.
class MathBlock extends StatelessWidget {
  const MathBlock({
    super.key,
    required this.latex,
    required this.plainText,
    required this.style,
    this.number,
  });

  final String latex;
  final String plainText;
  final BlockStyle style;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final src = normalizeLatexEscapes(latex);
    final fallbackText = plainText.isEmpty ? mathToPlain(src) : plainText;
    final Widget math = src.trim().isEmpty
        ? FormulaFallback(
            key: const ValueKey('formula-fallback'),
            text: fallbackText,
            style: style,
          )
        : Math.tex(
            src,
            textStyle: TextStyle(
              fontSize: 18 * style.scale,
              color: kc.textPrimary,
            ),
            onErrorFallback: (error) {
              logMathFailure(src, error.message);
              return FormulaFallback(
                key: const ValueKey('formula-fallback'),
                text: fallbackText,
                style: style,
              );
            },
          );
    final n = number;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: kc.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Center(child: math),
                  ),
                ),
              ),
            ),
            if (n != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: KSpace.sm),
                child: Text(
                  '($n)',
                  style: TextStyle(
                    color: kc.textSecondary,
                    fontSize: 14 * style.scale,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
