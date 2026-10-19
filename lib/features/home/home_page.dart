import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';

/// Home tab: flashcard feed, Continue card, streak (built in WP6).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ComingSoon(icon: Icons.auto_awesome, title: l10n.splashTagline),
    );
  }
}
