import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';
import '../auth/google_sign_in_button.dart';
import 'language_picker.dart';

/// Profile tab: account, language (full profile in WP7).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final signedIn = ref.watch(isSignedInProvider);
    final email = switch (ref.watch(sessionProvider)) {
      AsyncData(:final value) => value?.user.email,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: ComingSoon(
        icon: Icons.badge_outlined,
        title: l10n.profilePlaceholder,
        child: Column(
          children: [
            if (signedIn) ...[
              Text(
                l10n.signedInAs(email ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: kc.textSecondary),
              ),
              const SizedBox(height: KSpace.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    guard(ref.read(authRepositoryProvider).signOut),
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOut),
              ),
            ] else
              const GoogleSignInButton(),
            const SizedBox(height: KSpace.xl),
            Text(l10n.languageLabel, style: TextStyle(color: kc.textSecondary)),
            const SizedBox(height: KSpace.sm),
            const LanguagePicker(),
            const SizedBox(height: KSpace.xl),
            // Temporary glyph check (CONTENT_FORMAT 2): must show NO empty boxes.
            Text(
              '4Na + O\u2082 \u27F6 2Na\u2082\u1D35O   \u21CC   \u0394H',
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.accentText, fontSize: 18),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: KSpace.lg),
              TextButton(
                onPressed: () => context.go('/profile/states'),
                child: const Text('UI states (debug)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
