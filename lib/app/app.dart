import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../data/coins/coins_providers.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'sync_triggers.dart';

class KampusLinkApp extends ConsumerWidget {
  const KampusLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final accent = ref.watch(themeAccentProvider);
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightWith(accent),
      darkTheme: AppTheme.darkWith(accent),
      themeMode: ref.watch(themeModeProvider),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: resolveLocale,
      builder: (context, child) => SyncTriggers(
        child: UpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
