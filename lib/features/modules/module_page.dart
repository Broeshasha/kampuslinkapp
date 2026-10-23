import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/lessons/lesson_providers.dart';
import '../../data/lessons/lesson_repository.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../preview/preview_page.dart';
import 'download_status.dart';
import 'library_tab.dart';

/// One module: LESSONS (episodes grouped by unit) and LIBRARY (files).
/// Reads only the local database; downloading goes through the sync.
class ModulePage extends ConsumerWidget {
  const ModulePage({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(moduleProvider(moduleId))) {
      AsyncData(:final value) when value != null => _ModuleScaffold(
        module: value,
      ),
      AsyncData() => Scaffold(
        appBar: AppBar(),
        body: EmptyView(icon: Icons.search_off, title: l10n.errorNotFound),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(failure: mapError(error)),
      ),
      _ => const Scaffold(body: LoadingView()),
    };
  }
}

/// D-023 (founder): no PDF library for now; lessons are JSON (fast, offline,
/// themed). Flip to true to bring the Library tab back.
const showLibrary = false;

class _ModuleScaffold extends ConsumerWidget {
  const _ModuleScaffold({required this.module});

  final ModuleRow module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accent = moduleAccent(module.id);
    final title = Text(
      module.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final chat = IconButton(
      tooltip: l10n.chatTitle,
      icon: const Icon(Icons.forum_outlined),
      onPressed: () => context.go('/modules/${module.id}/chat'),
    );
    final drafts = ref.watch(previewDraftsProvider)
        ? IconButton(
            tooltip: l10n.previewTitle,
            icon: const Icon(Icons.drafts_outlined),
            onPressed: () => context.push('/preview/${module.id}'),
          )
        : null;
    if (!showLibrary) {
      return Scaffold(
        appBar: AppBar(title: title, actions: [?drafts, chat]),
        body: _LessonsTab(module: module),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'chat-${module.id}',
          backgroundColor: accent,
          foregroundColor: Colors.white,
          onPressed: () => context.go('/modules/${module.id}/chat'),
          icon: const Icon(Icons.forum_rounded),
          label: Text(l10n.chatTitle),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          actions: [?drafts, chat],
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            tabs: [
              Tab(text: l10n.moduleLessons),
              Tab(text: l10n.moduleLibrary),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LessonsTab(module: module),
            LibraryTab(moduleId: module.id),
          ],
        ),
      ),
    );
  }
}

class _LessonsTab extends ConsumerWidget {
  const _LessonsTab({required this.module});

  final ModuleRow module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final busy = ref.watch(
      syncControllerProvider.select((s) => s.downloading.contains(module.id)),
    );
    void download() => ref.read(syncControllerProvider.notifier).syncNow();

    // A module with some lessons stored is usable (lead brief 2, B4).
    return switch (ref.watch(lessonsProvider(module.id))) {
      AsyncData(:final value) when value.isNotEmpty => _LessonList(
        module: module,
        items: value,
        busy: busy,
        online: online,
        onUpdate: download,
      ),
      AsyncData() => _NothingStored(
        module: module,
        busy: busy,
        online: online,
        onDownload: download,
      ),
      AsyncError(:final error) => ErrorView(failure: mapError(error)),
      _ => const LoadingView(),
    };
  }
}

class _NothingStored extends ConsumerWidget {
  const _NothingStored({
    required this.module,
    required this.busy,
    required this.online,
    required this.onDownload,
  });

  final ModuleRow module;
  final bool busy;
  final bool online;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failure = ref.watch(
      syncControllerProvider.select((s) => s.failures[module.id]),
    );
    if (module.serverVersion == 0) {
      return EmptyView(
        icon: Icons.hourglass_empty_rounded,
        title: l10n.moduleNoLessons,
      );
    }
    if (busy || failure != null) {
      return ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [MaxWidth(child: ModuleDownloadStatus(module: module))],
      );
    }
    return EmptyView(
      icon: Icons.cloud_download_outlined,
      title: l10n.moduleNotDownloaded,
      message: online ? null : l10n.needInternetToDownload,
      actionLabel: online ? l10n.downloadModule : null,
      onAction: online ? onDownload : null,
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({
    required this.module,
    required this.items,
    required this.busy,
    required this.online,
    required this.onUpdate,
  });

  final ModuleRow module;
  final List<LessonItem> items;
  final bool busy;
  final bool online;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final accent = moduleAccent(module.id);
    final done = items.where((i) => i.done).length;
    final children = <Widget>[
      _ModuleHeader(
        module: module,
        done: done,
        total: items.length,
        accent: accent,
      ),
      ModuleDownloadStatus(
        module: module,
        fallback: module.serverVersion > module.localVersion
            ? _UpdateBanner(busy: busy, online: online, onUpdate: onUpdate)
            : null,
      ),
    ];
    String? currentUnit;
    var number = 0;
    for (final item in items) {
      final content = LessonContent.of(item.lesson, lang);
      if (content.unitKey != currentUnit) {
        currentUnit = content.unitKey;
        final n = content.unitNumber;
        final title = [
          if (n != null) l10n.chapterLabel(n),
          if (content.unitTitle.isNotEmpty) content.unitTitle,
        ].join(' \u00b7 ');
        if (title.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: KSpace.lg,
                bottom: KSpace.sm,
                start: KSpace.xs,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: kc.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }
      }
      number++;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: KSpace.sm),
          child: _LessonTile(
            number: number,
            title: content.title,
            minutes: item.lesson.estimatedMinutes,
            item: item,
            accent: accent,
            onTap: () =>
                context.go('/modules/${module.id}/lesson/${item.lesson.id}'),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.xxl * 3,
      ),
      children: [for (final c in children) MaxWidth(child: c)],
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({
    required this.module,
    required this.done,
    required this.total,
    required this.accent,
  });

  final ModuleRow module;
  final int done;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final ue = module.ueCategory;
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.card),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(KRadius.chip),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Text(
                  module.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          Row(
            children: [
              if (ue != null) ...[
                Text(
                  ue,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: KSpace.sm),
              ],
              Expanded(
                child: Text(
                  '$done / ${l10n.lessonsCount(total)}',
                  style: TextStyle(color: kc.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0.0 : done / total,
              minHeight: 8,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.busy,
    required this.online,
    required this.onUpdate,
  });

  final bool busy;
  final bool online;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Material(
        color: kc.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: KSpace.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: kc.accentText, size: 20),
              const SizedBox(width: KSpace.sm),
              Expanded(child: Text(l10n.moduleUpdateAvailable)),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (online)
                TextButton(onPressed: onUpdate, child: Text(l10n.updateAction)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.number,
    required this.title,
    required this.minutes,
    required this.item,
    required this.accent,
    required this.onTap,
  });

  final int number;
  final String title;
  final int? minutes;
  final LessonItem item;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final m = minutes;
    final status = item.status;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Row(
            children: [
              _StatusBadge(
                number: number,
                status: status,
                progress: item.readProgress,
                accent: accent,
              ),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (m != null || status == LessonStatus.inProgress)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (m != null) l10n.minutesShort(m),
                            if (status == LessonStatus.inProgress)
                              '${(item.readProgress * 100).round()}%',
                          ].join(' \u00b7 '),
                          style: TextStyle(
                            color: kc.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                rtl ? Icons.chevron_left : Icons.chevron_right,
                color: kc.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.number,
    required this.status,
    required this.progress,
    required this.accent,
  });

  final int number;
  final LessonStatus status;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    if (status == LessonStatus.done) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: accent,
        child: const Icon(Icons.check_rounded, color: Colors.white),
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: status == LessonStatus.inProgress ? progress : 0,
              strokeWidth: 3,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.18),
            ),
          ),
          Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: kc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
