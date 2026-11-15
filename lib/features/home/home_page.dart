import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/logging/startup_trace.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/cases/case_repository.dart';
import '../../data/shop/shop_models.dart' show parseHexColor;
import '../../data/shop/shop_providers.dart';
import '../../data/db/app_database.dart';
import '../../data/learning/content_meta.dart';
import '../../data/learning/feed_pool.dart';
import '../../data/learning/feed_queue.dart';
import '../../data/learning/feed_queue_provider.dart';
import '../../data/learning/feed_repository.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/lessons/figures.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/lessons/lesson_repository.dart';
import '../../data/profile/study_level.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/coming_soon.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../../render/latex_plain.dart';
import '../../render/math_text.dart';
import '../../ui/celebration_burst.dart';
import '../cases/case_models.dart';
import '../cases/case_set_view.dart';
import '../cases/report_sheet.dart';
import '../profile/semester_sheet.dart';
import '../profile/share_app.dart';
import 'feed_rail.dart';
import 'flash_card.dart';
import 'quick_question_card.dart';
import 'study_activity.dart';

/// Home tab: Continue + Shuffle above the
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: const Scaffold(
        body: StudyActivity(
          child: Stack(
            children: [
              Positioned.fill(child: _Feed()),
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: _HomeTop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height of the glass bar floating over the top of the feed.
const double kHomeTopBar = 60;

/// Module chips, Continue and Shuffle, floating over the card (no bar,
/// no blur: the post's colour runs to the top of the screen).
class _HomeTop extends ConsumerWidget {
  const _HomeTop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: KSpace.xs,
              end: KSpace.xs,
              top: KSpace.xs,
            ),
            child: MaxWidth(
              child: Row(
                children: [
                  const Expanded(child: _FeedChips()),
                  const _ResumeButton(),
                  IconButton(
                    tooltip: l10n.shuffleFeed,
                    onPressed: () =>
                        ref.read(feedQueueProvider.notifier).shuffle(),
                    icon: Icon(Icons.shuffle_rounded, color: kc.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SemesterBanner(),
        ],
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
    final visible = ref.watch(visibleModuleIdsProvider);
    final cases = <CaseSet>[
      for (final source in sources)
        if (visible.contains(source.moduleId))
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
                    MathText(
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
                    MathText(
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

  /// The post on screen: the fixed rail acts on it.
  int _index = 0;

  /// Likes / saves changed in this session (card id -> on).
  final Map<int, bool> _liked = <int, bool>{};
  final Map<int, bool> _saved = <int, bool>{};
  int _heartId = 0;
  bool _heart = false;
  int _burstId = 0;
  String? _burst;
  String? _fxStyle;
  Timer? _flushTimer;

  @override
  void dispose() {
    _flushTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  bool _isLiked(FeedCard c) => _liked[c.card.id] ?? c.liked;
  bool _isSaved(FeedCard c) => _saved[c.card.id] ?? c.saved;

  void _setLike(FeedCard c, bool on) {
    setState(() => _liked[c.card.id] = on);
    if (on) HapticFeedback.lightImpact();
    guard(() => ref.read(feedRepositoryProvider).setLiked(c.card.id, on: on));
  }

  void _setSave(FeedCard c, bool on) {
    setState(() => _saved[c.card.id] = on);
    guard(() => ref.read(feedRepositoryProvider).setSaved(c.card.id, on: on));
  }

  /// Double-tap a card = like, with a big heart in the middle.
  void _doubleLike(FeedCard c) {
    HapticFeedback.mediumImpact();
    if (!_isLiked(c)) _setLike(c, true);
    setState(() {
      _heart = true;
      _heartId++;
    });
  }

  /// Answers go out a few seconds later, in one batch.
  void _flushSoon() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !ref.read(isOnlineProvider)) return;
      final sync = ref.read(outboxSyncProvider);
      if (sync != null) unawaited(sync.flush());
    });
  }

  String _plain(String text) {
    final t = latexToPlain(text).trim();
    return t.length > 240 ? '${t.substring(0, 240)}...' : t;
  }

  void _more(
    BuildContext context, {
    required String targetType,
    required String targetId,
    int? lessonId,
    int? moduleId,
  }) {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lessonId != null && moduleId != null)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(l10n.learnThis),
                onTap: () {
                  Navigator.of(sheet).pop();
                  router.go('/modules/$moduleId/lesson/$lessonId');
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.reportMistake),
              onTap: () {
                Navigator.of(sheet).pop();
                showReportMistake(
                  context,
                  ref,
                  targetType: targetType,
                  targetId: targetId,
                  lessonId: lessonId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rail(BuildContext context, FeedItem item, String lang) {
    final payload = item.payload;
    if (payload is FeedCard) {
      final card = payload;
      return FeedRail(
        moduleName: card.module.name,
        accent: moduleAccent(card.module.id),
        onModule: () => context.go('/modules/${card.module.id}'),
        liked: _isLiked(card),
        onLike: () => _setLike(card, !_isLiked(card)),
        saved: _isSaved(card),
        onSave: () => _setSave(card, !_isSaved(card)),
        onShare: () => showShareSheet(
          context,
          shareMessage(_plain(card.text(lang).front)),
        ),
        onMore: () => _more(
          context,
          targetType: 'card',
          targetId: '${card.card.id}',
          lessonId: card.card.lessonId,
          moduleId: card.module.id,
        ),
      );
    }
    if (payload is FeedQuestion) {
      return FeedRail(
        moduleName: payload.module.name,
        accent: moduleAccent(payload.module.id),
        onModule: () => context.go('/modules/${payload.module.id}'),
        onShare: () => showShareSheet(
          context,
          shareMessage(_plain(payload.text(lang).prompt)),
        ),
        onMore: () => _more(
          context,
          targetType: 'question',
          targetId: '${payload.question.id}',
          lessonId: payload.question.lessonId,
          moduleId: payload.module.id,
        ),
      );
    }
    final source = payload as CaseSource;
    final set = CaseSet.fromSource(source.source, lang);
    final moduleId = source.moduleId;
    return FeedRail(
      moduleName: '',
      accent: moduleId == null ? context.kc.accent : moduleAccent(moduleId),
      onModule: moduleId == null
          ? null
          : () => context.go('/modules/$moduleId'),
      onMore: () => _more(
        context,
        targetType: 'set',
        targetId: set.id,
        lessonId: set.lessonId,
        moduleId: moduleId,
      ),
    );
  }

  Future<void> _next() async {
    if (!mounted || !_pages.hasClients) return;
    await _pages.nextPage(duration: KMotion.slow, curve: KMotion.curve);
  }

  Future<void> _answer(FeedItem item, FeedCard card, bool knewIt) async {
    final fx = _fxStyle;
    if (knewIt && fx != null) {
      setState(() {
        _burst = fx;
        _burstId++;
      });
    }
    _flushSoon();
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
    final pad = MediaQuery.paddingOf(context);
    final topInset = pad.top + kHomeTopBar;
    final bottomInset = pad.bottom;
    final payload = item.payload;
    if (payload is CaseSource) {
      final set = CaseSet.fromSource(payload.source, lang);
      return MaxWidth(
        child: CaseSetView(
          key: ValueKey<String>(item.key),
          fullBleed: true,
          endInset: FeedRail.width,
          topInset: topInset,
          bottomInset: bottomInset,
          set: set,
          seed: ref.read(authControllerProvider).userId ?? '',
          demo: payload.moduleId == null,
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
          fullBleed: true,
          endInset: FeedRail.width,
          topInset: topInset,
          bottomInset: bottomInset,
          prompt: text.prompt,
          options: text.options,
          correctIndex: payload.question.correctIndex,
          questionId: payload.question.id,
          shuffleSeed: ref.read(authControllerProvider).userId ?? '',
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
    final skin = ref
        .read(walletControllerProvider)
        ?.equippedPayload('card_skin');
    final skinBg = skin?['bg'];
    final skinColors = skinBg is List
        ? [for (final c in skinBg) ?parseHexColor(c)]
        : null;
    final figure = pickFigure(
      text: langText(card.card.i18nJson, text.language),
      shared: meta['c:${card.card.id}']?['figure'],
    );
    return MaxWidth(
      child: GestureDetector(
        onDoubleTap: () => _doubleLike(card),
        child: FlashCardView(
          key: ValueKey<String>(item.key),
          showRail: false,
          fullBleed: true,
          endInset: FeedRail.width,
          topInset: topInset,
          bottomInset: bottomInset,
          skinColors: skinColors != null && skinColors.length >= 2
              ? skinColors
              : null,
          skinText: parseHexColor(skin?['fg']),
          front: text.front,
          back: text.back,
          language: text.language,
          figure: figure,
          moduleName: card.module.name,
          accent: moduleAccent(card.module.id),
          liked: _isLiked(card),
          saved: _isSaved(card),
          onLearn: item.learn
              ? () => context.go(
                  '/modules/${card.module.id}/lesson/${card.card.lessonId}',
                )
              : null,
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
        if (_index != 0) setState(() => _index = 0);
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
    // Stale-while-revalidate: while the queue rebuilds, keep showing the
    // posts already on screen (never a spinner over cached content).
    final queue = ref.watch(feedQueueProvider);
    if (!queue.hasValue) {
      if (queue.hasError) {
        return ErrorView(
          failure: mapError(queue.error!),
          onRetry: () => ref.invalidate(feedQueueProvider),
        );
      }
      return const LoadingView();
    }
    final value = queue.requireValue;
    startupTrace.mark('home feed ready', '${value.length} posts');
    if (value.isEmpty) {
      return ref.watch(downloadedKeyProvider).isEmpty
          ? EmptyView(
              icon: Icons.style_outlined,
              title: l10n.feedEmptyTitle,
              message: l10n.feedEmptyBody,
              actionLabel: l10n.openModules,
              onAction: () => context.go('/modules'),
            )
          : const _FeedDone();
    }
    final fx = ref
        .watch(walletControllerProvider)
        ?.equippedPayload('celebration')?['style'];
    _fxStyle = fx is String ? fx : null;
    final current = _index < value.length ? value[_index] : null;
    // Only the cards move; the rail and the heart stay.
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            itemCount: value.length + 1,
            onPageChanged: (i) {
              setState(() => _index = i);
              ref.read(feedQueueProvider.notifier).shown(i);
            },
            itemBuilder: (context, i) => i == value.length
                ? const _FeedDone()
                : Padding(
                    padding: const EdgeInsetsDirectional.only(end: 0),
                    child: _post(
                      context,
                      value[i],
                      lang,
                      caseProgress,
                      hintSeen,
                      meta,
                    ),
                  ),
          ),
        ),
        if (current != null)
          PositionedDirectional(
            end: 0,
            bottom: KSpace.xl + MediaQuery.paddingOf(context).bottom,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : KMotion.normal,
              child: KeyedSubtree(
                key: ValueKey<String>(current.key),
                child: _rail(context, current, lang),
              ),
            ),
          ),
        if (_heart)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: BigHeart(
                  key: ValueKey<int>(_heartId),
                  onDone: () {
                    if (mounted) setState(() => _heart = false);
                  },
                ),
              ),
            ),
          ),
        if (_burst case final style?)
          Positioned.fill(
            child: CelebrationBurst(
              key: ValueKey<int>(_burstId),
              style: style,
              onDone: () {
                if (mounted) setState(() => _burst = null);
              },
            ),
          ),
      ],
    );
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

/// Feed brief B: "All" + one chip per visible module (French name). The
/// choice is remembered on the phone; switching shows a pre-built queue.
class _FeedChips extends ConsumerWidget {
  const _FeedChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = switch (ref.watch(visibleModulesProvider)) {
      AsyncData(:final value) => value,
      _ => const <ModuleRow>[],
    };
    if (modules.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final picked = ref.watch(feedModuleProvider);
    final selected = modules.any((m) => m.id == picked) ? picked : null;
    final kc = context.kc;
    Widget chip(int? id, String label) {
      final on = selected == id;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(feedQueueProvider.notifier).select(id),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Container(
                height: 34,
                alignment: Alignment.center,
                margin: const EdgeInsetsDirectional.only(end: KSpace.xs),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: on ? kc.textPrimary.withValues(alpha: 0.16) : null,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on ? kc.textPrimary : kc.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
        children: [
          chip(null, l10n.feedAllModules),
          for (final m in modules) chip(m.id, m.name),
        ],
      ),
    );
  }
}
