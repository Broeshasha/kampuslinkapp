import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';

/// Modules tab: module list -> lessons, library, quizzes, chat (WP5).
class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabModules)),
      body: ComingSoon(
        icon: Icons.menu_book_outlined,
        title: l10n.modulesPlaceholder,
      ),
    );
  }
}
