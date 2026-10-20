import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/logging/logger.dart';
import '../core/theme/tokens.dart';
import 'block_style.dart';

/// Inline \( ... \) math on the text baseline; raw text if it cannot parse.
class InlineMath extends StatelessWidget {
  const InlineMath({super.key, required this.latex, required this.style});

  final String latex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        latex,
        mathStyle: MathStyle.text,
        textStyle: style,
        onErrorFallback: (error) {
          appLog.warn('inline latex failed: $latex');
          return Text(latex, style: style);
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
    final fallbackText = plainText.isEmpty ? latex : plainText;
    final Widget math = latex.trim().isEmpty
        ? FormulaFallback(
            key: const ValueKey('formula-fallback'),
            text: fallbackText,
            style: style,
          )
        : Math.tex(
            latex,
            textStyle: TextStyle(
              fontSize: 18 * style.scale,
              color: kc.textPrimary,
            ),
            onErrorFallback: (error) {
              appLog.warn('latex failed, showing plain text: $latex');
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
