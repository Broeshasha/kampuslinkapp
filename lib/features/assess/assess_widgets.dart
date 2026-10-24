import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/assess/assess_models.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/code_block.dart';
import '../../render/compact_figure.dart';
import '../../render/rich_block_text.dart';
import '../../render/table_block.dart';

/// The content language of practice / exams = the UI language (the server
/// sends all three; French as fallback inside pickText).
String assessLang(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return supportedLanguageCodes.contains(code) ? code : fallbackLanguageCode;
}

BlockStyle assessStyle(BuildContext context, {double scale = 1.0}) {
  final lang = assessLang(context);
  return BlockStyle(
    language: lang,
    scale: scale,
    kc: context.kc,
    labels: lookupAppLocalizations(Locale(lang)),
    base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
  );
}

/// Rich text (LaTeX, code fences, inline code) like in lessons.
class AssessText extends StatelessWidget {
  const AssessText(this.text, {super.key, this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final style = assessStyle(context);
    return RichBlockText(
      text: text,
      shrinkMath: true,
      style: bold
          ? BlockStyle(
              language: style.language,
              scale: style.scale,
              kc: style.kc,
              labels: style.labels,
              base: style.base.copyWith(fontWeight: FontWeight.w700),
            )
          : style,
    );
  }
}

/// Figure + table + code of a statement / solution, each optional.
class AssessMedia extends StatelessWidget {
  const AssessMedia({super.key, this.figure, this.table, this.code});

  final Map<String, dynamic>? figure;
  final Map<String, dynamic>? table;
  final CodeSolution? code;

  @override
  Widget build(BuildContext context) {
    final style = assessStyle(context);
    final fig = figure;
    final tab = table;
    final c = code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fig != null)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.sm),
            child: CompactFigure(
              figure: fig,
              language: style.language,
              height: 200,
            ),
          ),
        if (tab != null)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.sm),
            child: TableBlock(block: tab, style: style),
          ),
        if (c != null)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.sm),
            child: CodeBlock(
              code: c.code,
              output: c.output,
              language: 'python',
              style: style,
            ),
          ),
      ],
    );
  }
}

/// A rounded section box.
class AssessBox extends StatelessWidget {
  const AssessBox({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final c = color;
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: c == null ? kc.surface : c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KRadius.chip),
        border: Border.all(color: c?.withValues(alpha: 0.5) ?? kc.border),
      ),
      child: child,
    );
  }
}

/// Numbered solution steps then the final answer.
class SolutionView extends StatelessWidget {
  const SolutionView({
    super.key,
    required this.steps,
    required this.answer,
    this.figure,
    this.code,
  });

  final List<String> steps;
  final String answer;
  final Map<String, dynamic>? figure;
  final CodeSolution? code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (steps.isNotEmpty)
          AssessBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.practiceSolution,
                  style: TextStyle(
                    color: kc.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}.',
                          style: TextStyle(
                            color: kc.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: KSpace.sm),
                        Expanded(child: AssessText(steps[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        AssessMedia(figure: figure, code: code),
        if (answer.trim().isNotEmpty) ...[
          const SizedBox(height: KSpace.sm),
          AssessBox(
            color: kc.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.practiceAnswer,
                  style: TextStyle(
                    color: kc.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: KSpace.xs),
                AssessText(answer),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
