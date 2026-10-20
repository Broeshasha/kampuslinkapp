import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import 'step_layout.dart';

/// Step 4: really downloads the module bundles, per-module state, skippable
/// (the sync keeps going in the background and resumes after a restart).
class DownloadStep extends ConsumerStatefulWidget {
  const DownloadStep({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  ConsumerState<DownloadStep> createState() => _DownloadStepState();
}

class _DownloadStepState extends ConsumerState<DownloadStep> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _started = true);
      await ref.read(syncControllerProvider.notifier).syncNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final modules = switch (ref.watch(modulesStreamProvider)) {
      AsyncData(:final value) => value,
      _ => const <ModuleRow>[],
    };
    final sync = ref.watch(syncControllerProvider);
    final withContent = modules.where((m) => m.serverVersion > 0).toList();
    final ready = withContent
        .where((m) => m.localVersion >= m.serverVersion)
        .length;
    final finished = _started && !sync.running;
    final double? progress = withContent.isEmpty
        ? (finished ? 1.0 : null)
        : ready / withContent.length;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.md),
        Text(
          l10n.downloadTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpace.lg),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: KSpace.sm),
        Text(
          l10n.downloadProgress(ready, withContent.length),
          style: TextStyle(color: kc.textSecondary),
        ),
        const SizedBox(height: KSpace.lg),
        for (final m in modules)
          _ModuleLine(module: m, downloading: sync.downloading.contains(m.id)),
      ],
      action: finished
          ? FilledButton(
              onPressed: widget.onFinish,
              child: Text(l10n.startLearning),
            )
          : TextButton(
              onPressed: widget.onFinish,
              child: Text(l10n.downloadSkip),
            ),
    );
  }
}

class _ModuleLine extends StatelessWidget {
  const _ModuleLine({required this.module, required this.downloading});

  final ModuleRow module;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final l10n = AppLocalizations.of(context);
    final accent = moduleAccent(module.id);
    final Widget status;
    if (module.serverVersion == 0) {
      status = Text(
        l10n.downloadNoContent,
        style: TextStyle(color: kc.textSecondary, fontSize: 12),
      );
    } else if (downloading) {
      status = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (module.localVersion >= module.serverVersion) {
      status = Icon(
        Icons.check_circle,
        color: kc.success,
        semanticLabel: l10n.downloadReady,
      );
    } else {
      status = Icon(Icons.schedule, color: kc.textSecondary);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Text(
              module.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: KSpace.sm),
          status,
        ],
      ),
    );
  }
}
