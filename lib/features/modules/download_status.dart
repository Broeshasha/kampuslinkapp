import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/download_issue.dart';

/// "Downloading 5 of 19 lessons", or the failure with Retry + Details, or
/// [fallback] (e.g. the "new content" banner) when nothing is going on.
class ModuleDownloadStatus extends ConsumerWidget {
  const ModuleDownloadStatus({super.key, required this.module, this.fallback});

  final ModuleRow module;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final sync = ref.watch(syncControllerProvider);
    final busy = sync.downloading.contains(module.id);
    final count = sync.progress[module.id];
    final failure = sync.failures[module.id];
    if (busy) {
      return Padding(
        padding: const EdgeInsets.only(top: KSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == null
                  ? l10n.syncing
                  : l10n.dlDownloadingLessons(count.done, count.total),
              style: TextStyle(color: kc.textSecondary),
            ),
            const SizedBox(height: KSpace.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count == null || count.total == 0
                    ? null
                    : count.done / count.total,
                minHeight: 6,
                color: moduleAccent(module.id),
              ),
            ),
          ],
        ),
      );
    }
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: KSpace.md),
        child: DownloadIssueCard(
          failure: failure,
          onRetry: () =>
              ref.read(syncControllerProvider.notifier).retryModule(module.id),
        ),
      );
    }
    return fallback ?? const SizedBox.shrink();
  }
}
