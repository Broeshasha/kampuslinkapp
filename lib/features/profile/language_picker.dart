import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// AR / FR / EN chips. Switching is instant (no restart) and remembered.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final names = {
      'ar': l10n.languageNameAr,
      'fr': l10n.languageNameFr,
      'en': l10n.languageNameEn,
    };
    return Wrap(
      spacing: KSpace.sm,
      runSpacing: KSpace.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final code in supportedLanguageCodes)
          ChoiceChip(
            label: Text(names[code]!),
            selected: current == code,
            onSelected: (_) =>
                ref.read(localeControllerProvider.notifier).setLanguage(code),
          ),
      ],
    );
  }
}
