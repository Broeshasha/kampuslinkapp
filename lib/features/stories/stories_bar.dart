import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart' show localized;
import '../../data/coins/coins_providers.dart';
import '../../data/coins/stories_models.dart';
import '../../l10n/app_localizations.dart';
import 'story_style.dart';
import 'story_viewer_page.dart';

/// The row of story circles at the top of Home. A coloured ring = something
/// not seen yet, a grey ring = all seen. Nothing is shown when there are no
/// stories (no empty row).
class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storiesControllerProvider);
    if (data == null) return const SizedBox.shrink();
    final groups = groupStories(data.stories);
    if (groups.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.lg,
          vertical: KSpace.xs,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: KSpace.md),
        itemBuilder: (context, i) => _StoryCircle(
          group: groups[i],
          data: data,
          onTap: () => openStoryViewer(context, groups, i),
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.group,
    required this.data,
    required this.onTap,
  });

  final StoryGroup group;
  final StoriesData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final kc = context.kc;
    final tpl = data.templateOf(group.lead.template);
    final label = group.isToday ? l10n.storiesToday : localized(tpl.name, lang);
    final icon = group.isToday ? Icons.wb_sunny_rounded : storyIcon(tpl.icon);
    final seen = group.allSeen;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.card),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seen ? kc.border : null,
                  gradient: seen
                      ? null
                      : LinearGradient(
                          colors: [tpl.accent, tpl.bg],
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                        ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tpl.bg,
                    border: Border.all(color: kc.background, width: 2),
                  ),
                  child: Icon(icon, color: tpl.fg, size: 28),
                ),
              ),
              const SizedBox(height: KSpace.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: seen ? kc.textSecondary : kc.textPrimary,
                  fontWeight: seen ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
