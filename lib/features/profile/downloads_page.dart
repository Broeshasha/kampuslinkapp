import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/profile/study_level.dart';
import '../../data/providers.dart';
import '../../data/sync/download_stats.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';

/// Stored size per module + everything else, refreshed after each sync.
final storedSizesProvider =
    FutureProvider<({Map<int, int> modules, int other})>((ref) async {
      ref.watch(syncControllerProvider.select((s) => s.running));
      final db = ref.watch(appDatabaseProvider);
      return (
        modules: await storedBytesPerModule(db),
        other: await storedOtherBytes(db),
      );
    });

/// The one sheet before the very first full download: the expected size,
/// "Continue" pre-selected (dismissing it also continues).
Future<bool> showFirstDownloadSheet(BuildContext context, int bytes) async {
  final l10n = AppLocalizations.of(context);
  final go = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.lg,
        KSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.downloadFirstTitle,
            style: Theme.of(sheet).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.sm),
          Text(l10n.downloadFirstBody(formatBytes(bytes))),
          const SizedBox(height: KSpace.lg),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(sheet).pop(true),
            child: Text(l10n.downloadContinue),
          ),
          const SizedBox(height: KSpace.xs),
          TextButton(
            onPressed: () => Navigator.of(sheet).pop(false),
            child: Text(l10n.downloadLater),
          ),
        ],
      ),
    ),
  );
  return go ?? true;
}

/// Profile > Downloads (feed brief C): size on the phone, per module, last
/// update, "Download now" and "Pause". Mobile data is allowed.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final sync = ref.watch(syncControllerProvider);
    final notifier = ref.read(syncControllerProvider.notifier);
    final online = ref.watch(isOnlineProvider);
    final modules = switch (ref.watch(visibleModulesProvider)) {
      AsyncData(:final value) => value,
      _ => const <ModuleRow>[],
    };
    final sizes = switch (ref.watch(storedSizesProvider)) {
      AsyncData(:final value) => value,
      _ => (modules: const <int, int>{}, other: 0),
    };
    final total =
        sizes.modules.values.fold<int>(0, (a, b) => a + b) + sizes.other;
    final checked = notifier.contentCheckedAt;
    final ml = MaterialLocalizations.of(context);
    final lastText = checked == null
        ? l10n.downloadsNever
        : l10n.downloadsLastUpdate(
            '${ml.formatShortDate(checked)} '
            '${ml.formatTimeOfDay(TimeOfDay.fromDateTime(checked))}',
          );
    final busy = sync.running && sync.downloading.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.downloadsOnPhone(formatBytes(total)),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: KSpace.xs),
                Text(lastText, style: TextStyle(color: kc.textSecondary)),
                const SizedBox(height: KSpace.xs),
                Text(
                  sync.paused ? l10n.downloadsPaused : l10n.downloadsMobileData,
                  style: TextStyle(color: kc.textSecondary),
                ),
                const SizedBox(height: KSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: !online || busy
                            ? null
                            : () => notifier.downloadNow(),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l10n.downloadNow),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sync.paused ? null : () => notifier.pause(),
                        icon: const Icon(Icons.pause_rounded),
                        label: Text(l10n.downloadPause),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.lg),
                for (final m in modules)
                  _ModuleRowTile(
                    module: m,
                    size: sizes.modules[m.id] ?? 0,
                    progress: sync.downloading.contains(m.id)
                        ? sync.progress[m.id]
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleRowTile extends StatelessWidget {
  const _ModuleRowTile({
    required this.module,
    required this.size,
    required this.progress,
  });

  final ModuleRow module;
  final int size;
  final LessonCount? progress;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final p = progress;
    final ready =
        module.serverVersion > 0 && module.localVersion >= module.serverVersion;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ready ? Icons.download_done_rounded : Icons.downloading_rounded,
        color: ready ? kc.success : kc.textSecondary,
      ),
      title: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: p == null
          ? null
          : LinearProgressIndicator(
              value: p.total == 0 ? null : p.done / p.total,
            ),
      trailing: Text(
        formatBytes(size),
        style: TextStyle(color: kc.textSecondary),
      ),
    );
  }
}
