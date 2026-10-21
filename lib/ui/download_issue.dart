import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/sync/download_failure.dart';
import '../l10n/app_localizations.dart';

String downloadMessage(AppLocalizations l10n, DownloadFailure f) =>
    switch (f.kind) {
      DownloadErrorKind.offline => l10n.dlOffline,
      DownloadErrorKind.timeout => l10n.dlTimeout,
      DownloadErrorKind.server => l10n.dlServer,
      DownloadErrorKind.storage => l10n.dlStorage,
      DownloadErrorKind.database => l10n.dlDatabase,
      DownloadErrorKind.unknown => l10n.dlUnknown,
    };

/// A failed module download: a human message, Retry, and a "Details"
/// expander with the exact step / code / time and a Copy button (lead
/// brief 2, B7) so the founder can send the real reason.
class DownloadIssueCard extends StatelessWidget {
  const DownloadIssueCard({super.key, required this.failure, this.onRetry});

  final DownloadFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final color = failure.kind == DownloadErrorKind.offline
        ? kc.textSecondary
        : kc.warning;
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.sm, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: KSpace.sm),
                  child: Icon(
                    failure.kind == DownloadErrorKind.offline
                        ? Icons.cloud_off_rounded
                        : Icons.error_outline_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: KSpace.sm),
                    child: Text(downloadMessage(l10n, failure)),
                  ),
                ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
              ],
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  l10n.dlDetails,
                  style: TextStyle(color: kc.textSecondary, fontSize: 13),
                ),
                childrenPadding: const EdgeInsets.only(bottom: KSpace.sm),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          failure.details,
                          style: TextStyle(
                            fontSize: 12,
                            color: kc.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.dlCopy,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: failure.details),
                          );
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.dlCopied)),
                          );
                        },
                      ),
                    ],
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
