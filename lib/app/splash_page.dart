import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Temporary WP2 page: proves l10n, RTL and the instant language switch.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final names = {
      'ar': l10n.languageNameAr,
      'fr': l10n.languageNameFr,
      'en': l10n.languageNameEn,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.splashTagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.languageLabel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final code in supportedLanguageCodes)
                      ChoiceChip(
                        label: Text(names[code]!),
                        selected: current == code,
                        onSelected: (_) => ref
                            .read(localeControllerProvider.notifier)
                            .setLanguage(code),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
