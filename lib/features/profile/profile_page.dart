import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';
import 'language_picker.dart';

/// Profile tab: account, language, reminders, delete account (WP7).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: ComingSoon(
        icon: Icons.badge_outlined,
        title: l10n.profilePlaceholder,
        child: Column(
          children: [
            Text(l10n.languageLabel, style: TextStyle(color: kc.textSecondary)),
            const SizedBox(height: KSpace.sm),
            const LanguagePicker(),
            const SizedBox(height: KSpace.xl),
            // Temporary glyph check (CONTENT_FORMAT 2): must show NO empty boxes.
            Text(
              'H\u2082SO\u2084   Na\u2082\u1D35O   \u27F6   \u21CC   \u0394H',
              style: TextStyle(color: kc.accentText, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
