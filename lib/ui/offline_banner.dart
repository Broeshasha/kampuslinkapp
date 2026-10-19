import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/connectivity.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';

/// Slim, animated "you're offline" bar. Collapses to nothing when online.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final kc = context.kc;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : KMotion.normal,
      curve: KMotion.curve,
      child: online
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: margin,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpace.lg,
                  vertical: KSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: kc.surfaceRaised,
                  borderRadius: BorderRadius.circular(KRadius.chip),
                  border: Border.all(color: kc.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 18, color: kc.warning),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).offlineBanner,
                        style: TextStyle(color: kc.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
