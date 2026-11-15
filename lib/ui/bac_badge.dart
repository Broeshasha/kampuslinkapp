import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';

/// B17: "📜 Bac 2019" on items taken from a real bac exam. The text comes
/// from the app's own labels (never free text from the server).
class BacBadge extends StatelessWidget {
  const BacBadge({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: kc.xp.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Text(
          '📜 ${AppLocalizations.of(context).bacBadge(year)}',
          style: TextStyle(
            color: kc.xp,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
