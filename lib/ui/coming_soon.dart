import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';
import 'max_width.dart';

/// Temporary body for tabs that are not built yet (scrolls, never overflows).
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    this.child,
  });

  final IconData icon;
  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.xl),
      child: MaxWidth(
        child: Column(
          children: [
            const SizedBox(height: KSpace.xxl),
            Icon(icon, size: 56, color: kc.accentText),
            const SizedBox(height: KSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              AppLocalizations.of(context).comingSoon,
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.textSecondary),
            ),
            if (child != null) ...[const SizedBox(height: KSpace.xl), child!],
          ],
        ),
      ),
    );
  }
}
