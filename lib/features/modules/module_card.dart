import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../l10n/app_localizations.dart';

/// One module: its own accent colour (id mod 12) on the icon tile, the UE
/// tag and the progress ring.
class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.module, this.downloading = false});

  final ModuleRow module;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final l10n = AppLocalizations.of(context);
    final accent = moduleAccent(module.id);
    final total = module.lessonCount;
    final progress = total == 0
        ? 0.0
        : (module.lessonsDone / total).clamp(0.0, 1.0).toDouble();
    final ue = module.ueCategory;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: BorderRadius.circular(KRadius.card),
        border: Border.all(color: kc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Icon(Icons.menu_book_rounded, color: accent),
            ),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: KSpace.xs),
                  Wrap(
                    spacing: KSpace.sm,
                    runSpacing: KSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ue != null) _Tag(text: ue, color: accent),
                      Text(
                        l10n.lessonsCount(total),
                        style: TextStyle(color: kc.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpace.md),
            _ProgressRing(progress: progress, color: accent, busy: downloading),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.busy,
  });

  final double progress;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final percent = '${(progress * 100).round()}%';
    return Semantics(
      label: percent,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: busy ? null : progress,
                strokeWidth: 4,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            if (!busy)
              Text(
                percent,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.kc.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
