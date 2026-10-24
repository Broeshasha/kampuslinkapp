import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/assess/assess_providers.dart';
import '../../l10n/app_localizations.dart';

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// On the module page: "Practice" and "Mock exams", only when the module
/// has some (from its manifest).
class AssessEntries extends ConsumerWidget {
  const AssessEntries({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final practice =
        ref.watch(practiceIndexProvider(moduleId)).value ?? const [];
    final exams = ref.watch(examIndexProvider(moduleId)).value ?? const [];
    final count = practice.fold<int>(0, (a, c) => a + _n(c['count']));
    if (practice.isEmpty && exams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Row(
        children: [
          if (practice.isNotEmpty)
            Expanded(
              child: _Entry(
                key: const ValueKey('entry-practice'),
                icon: Icons.edit_note_rounded,
                title: l10n.practiceTitle,
                subtitle: l10n.practiceCount(count),
                onTap: () => context.push('/modules/$moduleId/practice'),
              ),
            ),
          if (practice.isNotEmpty && exams.isNotEmpty)
            const SizedBox(width: KSpace.sm),
          if (exams.isNotEmpty)
            Expanded(
              child: _Entry(
                key: const ValueKey('entry-exams'),
                icon: Icons.assignment_outlined,
                title: l10n.examsTitle,
                subtitle: l10n.examCount(exams.length),
                onTap: () => context.push('/modules/$moduleId/exams'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: kc.accent.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: kc.accentText),
              const SizedBox(height: KSpace.xs),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kc.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
