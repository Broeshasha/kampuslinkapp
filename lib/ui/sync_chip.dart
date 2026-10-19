import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_repository.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/sync/sync_controller.dart';
import '../l10n/app_localizations.dart';

/// Quiet "Syncing... / Synced" chip for app bars.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSignedInProvider)) return const SizedBox.shrink();
    final sync = ref.watch(syncControllerProvider);
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final Widget content;
    if (sync.running) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: KSpace.xs),
          Text(
            l10n.syncing,
            style: TextStyle(fontSize: 12, color: kc.textSecondary),
          ),
        ],
      );
    } else if (sync.lastSyncedAt != null && sync.failure == null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_outlined, size: 16, color: kc.success),
          const SizedBox(width: KSpace.xs),
          Text(
            l10n.synced,
            style: TextStyle(fontSize: 12, color: kc.textSecondary),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: KSpace.lg),
      child: Center(child: content),
    );
  }
}
