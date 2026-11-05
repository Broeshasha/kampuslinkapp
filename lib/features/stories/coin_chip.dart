import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/coins/coins_providers.dart';
import '../../l10n/app_localizations.dart';

/// The coin counter of Home. Tap = the Shop. Hidden until the first wallet
/// answer, so nobody sees a fake "0".
class CoinChip extends ConsumerWidget {
  const CoinChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    if (wallet == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Semantics(
      button: true,
      label: l10n.coinsBalance(wallet.balance),
      child: InkWell(
        onTap: () => context.push('/shop'),
        borderRadius: BorderRadius.circular(KRadius.chip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.md,
                vertical: KSpace.xs + 2,
              ),
              decoration: BoxDecoration(
                color: kc.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.chip),
                border: Border.all(color: kc.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded, size: 20, color: kc.xp),
                  const SizedBox(width: KSpace.xs),
                  Text(
                    '${wallet.balance}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
