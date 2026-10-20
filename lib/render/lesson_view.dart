import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';
import '../ui/max_width.dart';
import 'block_style.dart';
import 'block_view.dart';

/// A lesson = a lazy list of student blocks (CONTENT_FORMAT 5.1). The lesson
/// language decides direction and block labels, independent of the UI.
class LessonView extends StatelessWidget {
  const LessonView({
    super.key,
    required this.blocks,
    required this.language,
    this.scale = 1.0,
    this.controller,
  });

  final List<Map<String, dynamic>> blocks;
  final String language;
  final double scale;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final lang = supportedLanguageCodes.contains(language)
        ? language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: scale,
      kc: context.kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    return Directionality(
      textDirection: style.direction,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          KSpace.lg,
          KSpace.md,
          KSpace.lg,
          KSpace.xxl,
        ),
        itemCount: blocks.length,
        itemBuilder: (context, i) {
          final block = blocks[i];
          return MaxWidth(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpace.md),
              child: BlockView(
                key: ValueKey<String>('${block['id']}'),
                block: block,
                style: style,
              ),
            ),
          );
        },
      ),
    );
  }
}
