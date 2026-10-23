import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/cases/case_repository.dart';
import '../../data/learning/content_meta.dart';
import '../../data/learning/feed_pool.dart';
import '../../data/learning/feed_queue.dart';
import '../../data/learning/feed_queue_provider.dart';
import '../../data/learning/feed_repository.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/lessons/figures.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/lessons/lesson_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../cases/case_models.dart';
import '../cases/case_set_view.dart';
import '../cases/demo_cases.dart';
import '../cases/report_sheet.dart';
import 'flash_card.dart';
import 'quick_question_card.dart';
import 'study_activity.dart';
import 'year_question_card.dart';

int _int(Object? v, int fallback) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

/// Home tab: streak / XP / today's goal, the Continue card and the
/// social-media style feed (known cards, due cards, new cards in chapter
/// order, carousel sets, quick questions). Signed out: the welcome screen.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!ref.watch(isSignedInProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle)),
        body: ComingSoon(icon: Icons.auto_awesome, title: l10n.splashTagline),
      );
    }
    return const Scaffold(
      body: SafeArea(
        bottom: false,
        child: StudyActivity(
          child: Column(
            children: [
              _HomeHeader(),
              YearQuestionCard(),
              Expanded(child: _Feed()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final me = switch (ref.watch(serverStatsProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final days = switch (ref.watch(studyDaysProvider)) {
      AsyncData(:final value) => value,
      _ => const <String, int>{},
    };
    final now = DateTime.now();
    // Lead rule: the server streak is the truth once known; the local
    // count is only a fallback before the first successful fetch.
    final serverStreak = me?['current_streak'];
    final streak = serverStreak == null
        ? localStreak(days, now)
        : _int(serverStreak, 0);
    final xp = _int(me?['xp'], 0);
    final goal = _int(me?['study_goal_minutes'], 20).clamp(1, 600);
    final todayMinutes = (days[dayKey(now)] ?? 0) ~/ 60;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.md,
        KSpace.xs,
      ),
      child: MaxWidth(
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const _ResumeButton(),
            IconButton(
              tooltip: l10n.shuffleFeed,
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(feedQueueProvider.notifier).shuffle(),
              icon: Icon(Icons.shuffle_rounded, color: kc.textSecondary),
            ),
            _StatChip(
              icon: Icons.local_fire_department_rounded,
              color: kc.streak,
              value: '$streak',
              tooltip: l10n.streakLabel,
            ),
            const SizedBox(width: KSpace.xs),
            _StatChip(
              icon: Icons.bolt_rounded,
              color: kc.xp,
              value: '$xp',
              tooltip: l10n.xpLabel,
            ),
            const SizedBox(width: KSpace.sm),
            Tooltip(
              message: l10n.todayMinutes(todayMinutes, goal),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (todayMinutes / goal).clamp(0.0, 1.0),
                        strokeWidth: 4,
                        color: kc.success,
                        backgroundColor: kc.success.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      '$todayMinutes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 2),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue where you left off" lives in the header (one round button
/// with a dot), so the feed card keeps the whole screen. Tap = a sheet
/// with the unfinished lessons and the open case.
class _ResumeButton extends ConsumerWidget {
  const _ResumeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = switch (ref.watch(continueProvider)) {
      AsyncData(:final value) => value.take(3).toList(),
      _ => const <ContinueItem>[],
    };
    final progress = switch (ref.watch(caseProgressProvider)) {
      AsyncData(:final value) => value,
      _ => const <String, CaseProgress>{},
    };
    final sources = switch (ref.watch(caseSourcesProvider)) {
      AsyncData(:final value) => value,
      _ => const <CaseSource>[],
    };
    final lang = Localizations.localeOf(context).languageCode;
    final cases = <CaseSet>[
      for (final source in sources)
        if (progress[source.id] case final p? when p.started && !p.finished)
          CaseSet.fromSource(source.source, lang),
    ].take(2).toList();
    if (lessons.isEmpty && cases.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return IconButton(
      tooltip: l10n.resumeTitle,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final router = GoRouter.of(context);
        showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheet) => _ResumeSheet(
            lessons: lessons,
            cases: cases,
            onLesson: (item) {
              Navigator.of(sheet).pop();
              router.go('/modules/${item.module.id}/lesson/${item.lesson.id}');
            },
            onCase: (set) {
              Navigator.of(sheet).pop();
              router.push('/case/${set.id}');
            },
          ),
        );
      },
      icon: Badge(
        smallSize: 8,
        backgroundColor: kc.accent,
        child: Icon(Icons.play_circle_outline_rounded, color: kc.accentText),
      ),
    );
  }
}

class _ResumeSheet extends StatelessWidget {
  const _ResumeSheet({
    required this.lessons,
    required this.cases,
    required this.onLesson,
    required this.onCase,
  });

  final List<ContinueItem> lessons;
  final List<CaseSet> cases;
  final ValueChanged<ContinueItem> onLesson;
  final ValueChanged<CaseSet> onCase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
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
          Text(l10n.resumeTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: KSpace.md),
          for (final item in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: _ContinueLessonTile(
                item: item,
                onTap: () => onLesson(item),
              ),
            ),
          for (final set in cases)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: _ContinueCaseTile(set: set, onTap: () => onCase(set)),
            ),
        ],
      ),
    );
  }
}

class _ContinueLessonTile extends StatelessWidget {
  const _ContinueLessonTile({required this.item, required this.onTap});

  final ContinueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final accent = moduleAccent(item.module.id);
    final lang = Localizations.localeOf(context).languageCode;
    final title = LessonContent.of(item.lesson, lang).title;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, color: accent, size: 36),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.continueLabel} \u00b7 ${item.module.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: KSpace.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.position.progress,
                        minHeight: 4,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCaseTile extends StatelessWidget {
  const _ContinueCaseTile({required this.set, required this.onTap});

  final CaseSet set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: kc.accentAlt.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: kc.accentAlt, size: 28),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.continueCase,
                      style: TextStyle(
                        color: kc.accentAlt,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      set.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feed extends ConsumerStatefulWidget {
  const _Feed();

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!mounted || !_pages.hasClients) return;
    await _pages.nextPage(duration: KMotion.slow, curve: KMotion.curve);
  }

  Future<void> _answer(FeedItem item, FeedCard card, bool knewIt) async {
    await guard(
      () => ref
          .read(progressRepositoryProvider)
          .reviewCard(card.card.id, correct: knewIt),
    );
    ref
        .read(feedQueueProvider.notifier)
        .outcome(item.key, knewIt ? 'right' : 'wrong');
    await _next();
  }

  Widget _post(
    BuildContext context,
    FeedItem item,
    String lang,
    Map<String, CaseProgress> caseProgress,
    bool hintSeen,
    Map<String, Map<String, dynamic>> meta,
  ) {
    final feed = ref.read(feedRepositoryProvider);
    final payload = item.payload;
    if (payload is CaseSource) {
      final set = CaseSet.fromSource(payload.source, lang);
      return MaxWidth(
        child: CaseSetView(
          key: ValueKey<String>(item.key),
          set: set,
          demo: kShowDemoCases && payload.moduleId == null,
          accent: payload.moduleId == null
              ? null
              : moduleAccent(payload.moduleId!),
          progress: caseProgress[set.id] ?? CaseProgress(setId: set.id),
          showSwipeHint: !hintSeen,
          onHintSeen: () {
            guard(() => ref.read(caseRepositoryProvider).markHintSeen());
            ref.invalidate(caseHintSeenProvider);
          },
          onProgress: (p) =>
              guard(() => ref.read(caseRepositoryProvider).save(p)),
          onNext: _next,
          onReport: (_) => showReportMistake(
            context,
            ref,
            targetType: 'set',
            targetId: set.id,
            lessonId: set.lessonId,
          ),
        ),
      );
    }
    if (payload is FeedQuestion) {
      final text = payload.text(lang);
      final local = langText(payload.question.i18nJson, text.language);
      final shared = meta['q:${payload.question.id}'];
      return MaxWidth(
        child: QuickQuestionCard(
          key: ValueKey<String>(item.key),
          prompt: text.prompt,
          options: text.options,
          correctIndex: payload.question.correctIndex,
          explanation: text.explanation,
          language: text.language,
          figure: pickFigure(text: local, shared: shared?['figure']),
          optionFigures: pickOptionFigures(
            text: local,
            shared: shared?['option_figures'],
            count: text.options.length,
          ),
          moduleName: payload.module.name,
          accent: moduleAccent(payload.module.id),
          onAnswered: (right) => ref
              .read(feedQueueProvider.notifier)
              .outcome(item.key, right ? 'right' : 'wrong'),
          onReport: () => showReportMistake(
            context,
            ref,
            targetType: 'question',
            targetId: '${payload.question.id}',
            lessonId: payload.question.lessonId,
          ),
        ),
      );
    }
    final card = payload as FeedCard;
    final text = card.text(lang);
    final figure = pickFigure(
      text: langText(card.card.i18nJson, text.language),
      shared: meta['c:${card.card.id}']?['figure'],
    );
    return MaxWidth(
      child: FlashCardView(
        key: ValueKey<String>(item.key),
        front: text.front,
        back: text.back,
        language: text.language,
        figure: figure,
        moduleName: card.module.name,
        accent: moduleAccent(card.module.id),
        liked: card.liked,
        saved: card.saved,
        onAnswer: (knewIt) => _answer(item, card, knewIt),
        onLike: (on) => guard(() => feed.setLiked(card.card.id, on: on)),
        onSave: (on) => guard(() => feed.setSaved(card.card.id, on: on)),
        onReport: () => showReportMistake(
          context,
          ref,
          targetType: 'card',
          targetId: '${card.card.id}',
          lessonId: card.card.lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    ref.listen<AsyncValue<List<FeedItem>>>(feedQueueProvider, (prev, next) {
      final a = prev?.value;
      final b = next.value;
      if (b == null || !_pages.hasClients) return;
      if (a == null || a.isEmpty || b.isEmpty || a.first.key != b.first.key) {
        _pages.jumpToPage(0);
      }
    });
    final caseProgress = switch (ref.watch(caseProgressProvider)) {
      AsyncData(:final value) => value,
      _ => const <String, CaseProgress>{},
    };
    final meta = switch (ref.watch(contentMetaProvider)) {
      AsyncData(:final value) => value,
      _ => const <String, Map<String, dynamic>>{},
    };
    final hintSeen = switch (ref.watch(caseHintSeenProvider)) {
      AsyncData(:final value) => value,
      _ => true,
    };
    return switch (ref.watch(feedQueueProvider)) {
      AsyncData(:final value) when value.isEmpty =>
        ref.watch(downloadedKeyProvider).isEmpty
            ? EmptyView(
                icon: Icons.style_outlined,
                title: l10n.feedEmptyTitle,
                message: l10n.feedEmptyBody,
                actionLabel: l10n.openModules,
                onAction: () => context.go('/modules'),
              )
            : const _FeedDone(),
      AsyncData(:final value) => PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: value.length + 1,
        onPageChanged: (i) => ref.read(feedQueueProvider.notifier).shown(i),
        itemBuilder: (context, i) => i == value.length
            ? const _FeedDone()
            : _post(context, value[i], lang, caseProgress, hintSeen, meta),
      ),
      AsyncError(:final error) => ErrorView(
        failure: mapError(error),
        onRetry: () => ref.invalidate(feedQueueProvider),
      ),
      _ => const LoadingView(),
    };
  }
}

class _FeedDone extends ConsumerWidget {
  const _FeedDone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final next = switch (ref.watch(nextDueProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    String? dueText;
    if (next != null) {
      final ml = MaterialLocalizations.of(context);
      final time = ml.formatTimeOfDay(TimeOfDay.fromDateTime(next));
      final now = DateTime.now();
      final sameDay =
          next.year == now.year &&
          next.month == now.month &&
          next.day == now.day;
      dueText = sameDay ? time : '${ml.formatShortMonthDay(next)} $time';
    }
    return EmptyView(
      icon: Icons.celebration_rounded,
      title: l10n.feedDoneTitle,
      message: dueText == null
          ? l10n.feedDoneNoMore
          : l10n.feedDoneNext(dueText),
      actionLabel: next == null ? null : l10n.practiseAhead,
      onAction: next == null
          ? null
          : () {
              ref.read(feedAheadProvider.notifier).set(ahead: true);
              ref.invalidate(feedProvider);
              ref.invalidate(feedQueueProvider);
            },
    );
  }
}
