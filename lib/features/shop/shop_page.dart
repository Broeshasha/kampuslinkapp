import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart' show localized;
import '../../data/shop/shop_models.dart';
import '../../data/shop/shop_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

/// The Shop: streak freeze, skins, helpers. Paid with XP, which only comes
/// from studying; nothing here is bought with money and nothing is random.
class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final wallet = ref.watch(walletControllerProvider);
    final items = ref.watch(shopItemsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shopTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shopItemsProvider);
          await ref.read(walletControllerProvider.notifier).refresh();
        },
        child: MaxWidth(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(KSpace.lg),
            children: [
              if (wallet != null) _Balance(wallet: wallet),
              const SizedBox(height: KSpace.sm),
              Text(
                l10n.shopHint,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: kc.textSecondary),
              ),
              const SizedBox(height: KSpace.lg),
              switch (items) {
                AsyncData(:final value) =>
                  value.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(KSpace.xl),
                          child: Text(
                            l10n.shopEmpty,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in value)
                              _ItemTile(item: item, wallet: wallet),
                          ],
                        ),
                AsyncError() => Padding(
                  padding: const EdgeInsets.all(KSpace.xl),
                  child: Text(l10n.shopOffline, textAlign: TextAlign.center),
                ),
                _ => const LoadingView(),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: kc.xp, size: 40),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${wallet.balance} XP',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({required this.item, required this.wallet});

  final ShopItem item;
  final Wallet? wallet;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _busy = false;

  String _message(AppLocalizations l10n, String code) => switch (code) {
    'insufficient_xp' || 'insufficient_coins' => l10n.shopNotEnough,
    'freeze_limit' => l10n.shopMax,
    'offline' => l10n.errorOffline,
    _ => l10n.errorUnknown,
  };

  Future<void> _run(Future<String?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final code = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(code == null ? l10n.shopBought : _message(l10n, code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final kc = context.kc;
    final item = widget.item;
    final wallet = widget.wallet;
    final notifier = ref.read(walletControllerProvider.notifier);
    final owned = wallet?.owns(item.id) ?? false;
    final equipped = wallet?.isEquipped(item.id) ?? false;
    final balance = wallet?.balance ?? 0;
    final swatch = parseHexColor(item.payload['primary']);

    Widget? action;
    String? note;
    if (item.isFreeze) {
      final have = item.isWeekFreeze
          ? wallet?.weekFreezes ?? 0
          : wallet?.freezes ?? 0;
      final max = item.isWeekFreeze
          ? wallet?.maxWeekFreezes ?? 0
          : wallet?.maxFreezes ?? 0;
      note = l10n.shopHave(have, max);
      final full = max > 0 && have >= max;
      action = FilledButton(
        onPressed: _busy || full || balance < item.price
            ? null
            : () => _run(() => notifier.buy(item.id)),
        child: Text(full ? l10n.shopMax : '${l10n.shopBuy} · ${item.price} XP'),
      );
    } else if (owned) {
      action = equipped
          ? FilledButton.tonal(onPressed: null, child: Text(l10n.shopInUse))
          : FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() => notifier.equip(item.id)),
              child: Text(l10n.shopUse),
            );
    } else {
      action = FilledButton(
        onPressed: _busy || balance < item.price
            ? null
            : () => _run(() => notifier.buy(item.id)),
        child: Text('${l10n.shopBuy} · ${item.price} XP'),
      );
    }
    final notEnough =
        !owned &&
        !(item.isFreeze &&
            (item.isWeekFreeze
                    ? (wallet?.weekFreezes ?? 0) >= (wallet?.maxWeekFreezes ?? 1 << 20)
                    : (wallet?.freezes ?? 0) >= (wallet?.maxFreezes ?? 1 << 20))) &&
        balance < item.price;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatch ?? kc.surfaceRaised,
                  border: Border.all(color: kc.border),
                ),
                child: Icon(
                  item.isFreeze ? Icons.ac_unit_rounded : Icons.palette_rounded,
                  color: swatch == null ? kc.textSecondary : Colors.white,
                ),
              ),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localized(item.name, lang),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      localized(item.desc, lang),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: kc.textSecondary),
                    ),
                    if (note != null)
                      Text(
                        note,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kc.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (notEnough)
                      Text(
                        l10n.shopNotEnough,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: kc.warning),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.sm),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
