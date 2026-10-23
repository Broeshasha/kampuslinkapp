import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/compact_figure.dart';
import '../../render/rich_block_text.dart';

/// Feed post Q: one MCQ about something the student knows. One tap answers
/// it; the right option and the explanation show at once.
class QuickQuestionCard extends StatefulWidget {
  const QuickQuestionCard({
    super.key,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.language,
    required this.moduleName,
    required this.accent,
    required this.onAnswered,
    this.onReport,
    this.figure,
    this.optionFigures = const [],
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String language;
  final String moduleName;
  final Color accent;
  final ValueChanged<bool> onAnswered;
  final VoidCallback? onReport;

  /// Optional diagram under the prompt, and one per option (WP16 B).
  final Map<String, dynamic>? figure;
  final List<Map<String, dynamic>?> optionFigures;

  @override
  State<QuickQuestionCard> createState() => _QuickQuestionCardState();
}

class _QuickQuestionCardState extends State<QuickQuestionCard> {
  int? _answer;

  void _pick(int i) {
    if (_answer != null) return;
    HapticFeedback.selectionClick();
    setState(() => _answer = i);
    widget.onAnswered(i == widget.correctIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = supportedLanguageCodes.contains(widget.language)
        ? widget.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: 1.1,
      kc: kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    final answer = _answer;
    return Directionality(
      textDirection: style.direction,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpace.md,
          KSpace.xs,
          KSpace.md,
          KSpace.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kc.surface,
            borderRadius: BorderRadius.circular(KRadius.sheet),
            border: Border.all(color: widget.accent.withValues(alpha: 0.45)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: widget.accent, size: 18),
                    const SizedBox(width: KSpace.xs),
                    Expanded(
                      child: Text(
                        '${l10n.roleQuiz.toUpperCase()} \u00b7 ${widget.moduleName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.onReport != null)
                      IconButton(
                        tooltip: l10n.reportMistake,
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onReport,
                        icon: Icon(
                          Icons.flag_outlined,
                          color: kc.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: KSpace.md),
                RichBlockText(
                  text: widget.prompt,
                  style: BlockStyle(
                    language: style.language,
                    scale: style.scale * 1.1,
                    kc: kc,
                    labels: style.labels,
                    base: style.base.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (widget.figure case final fig?) ...[
                  const SizedBox(height: KSpace.md),
                  CompactFigure(
                    figure: fig,
                    language: style.language,
                    height: 160,
                  ),
                ],
                const SizedBox(height: KSpace.md),
                OptionGrid(
                  count: widget.options.length,
                  withFigures: widget.optionFigures.isNotEmpty,
                  itemBuilder: (context, i) =>
                      _option(context, i, answer, style),
                ),
                if (answer != null) ...[
                  Text(
                    answer == widget.correctIndex
                        ? l10n.quickRight
                        : l10n.quickWrong,
                    style: TextStyle(
                      color: answer == widget.correctIndex
                          ? kc.success
                          : kc.accentText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.explanation.isNotEmpty) ...[
                    const SizedBox(height: KSpace.xs),
                    RichBlockText(text: widget.explanation, style: style),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, int i, int? answer, BlockStyle style) {
    final kc = context.kc;
    final right = i == widget.correctIndex;
    final color = answer == null
        ? kc.border
        : right
        ? kc.success
        : i == answer
        ? kc.danger
        : kc.border;
    return Material(
      key: ValueKey<String>('option-$i'),
      color: answer != null && (right || i == answer)
          ? color.withValues(alpha: 0.14)
          : kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.button),
        side: BorderSide(color: color, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: answer == null ? () => _pick(i) : null,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: _optionBody(i, style),
        ),
      ),
    );
  }

  Widget _optionBody(int i, BlockStyle style) {
    final text = RichBlockText(text: widget.options[i], style: style);
    final fig = i < widget.optionFigures.length
        ? widget.optionFigures[i]
        : null;
    if (fig == null) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactFigure(
          figure: fig,
          language: style.language,
          height: 96,
          showCaption: false,
          zoomButton: true,
        ),
        const SizedBox(height: KSpace.xs),
        text,
      ],
    );
  }
}
