import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/catalog/catalog.dart' show localized;
import '../../data/coins/coins_models.dart';
import '../../data/coins/coins_providers.dart';
import '../../data/coins/stories_models.dart';
import '../../l10n/app_localizations.dart';
import '../profile/share_app.dart';
import 'story_style.dart';
import 'story_templates.dart';

/// Opens the full-screen viewer above the tab bar.
Future<void> openStoryViewer(
  BuildContext context,
  List<StoryGroup> groups,
  int start,
) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: reduce ? Duration.zero : KMotion.normal,
      reverseTransitionDuration: reduce ? Duration.zero : KMotion.fast,
      pageBuilder: (_, _, _) =>
          StoryViewerPage(groups: groups, startGroup: start),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Instagram-style viewer. Tap the "next" side = next, the other side =
/// previous (both swap in Arabic), hold = pause, swipe down = close, swipe
/// sideways = next circle. Normal stories run for the template duration;
/// interactive ones wait until the student answers.
class StoryViewerPage extends ConsumerStatefulWidget {
  const StoryViewerPage({super.key, required this.groups, this.startGroup = 0});

  final List<StoryGroup> groups;
  final int startGroup;

  @override
  ConsumerState<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pages;
  late final AnimationController _timer;
  int _group = 0;
  final Map<int, int> _segment = <int, int>{};
  bool _holding = false;
  bool _closing = false;
  int? _flyCoins;
  int _flyId = 0;

  List<StoryGroup> get _groups => widget.groups;
  int get _seg => _segment[_group] ?? 0;

  @override
  void initState() {
    super.initState();
    _group = widget.startGroup.clamp(0, _groups.length - 1);
    _pages = PageController(initialPage: _group);
    _timer = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _segment[_group] = _firstUnseen(_group);
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _timer.dispose();
    _pages.dispose();
    super.dispose();
  }

  int _firstUnseen(int gi) {
    final list = _groups[gi].stories;
    for (var i = 0; i < list.length; i++) {
      if (!list[i].seen) return i;
    }
    return 0;
  }

  Story _latest(Story base, StoriesData? data) {
    if (data != null) {
      for (final s in data.stories) {
        if (s.key == base.key) return s;
      }
    }
    return base;
  }

  Story _current() {
    final list = _groups[_group].stories;
    return _latest(
      list[_seg.clamp(0, list.length - 1)],
      ref.read(storiesControllerProvider),
    );
  }

  StoryTemplate _templateOf(Story s) =>
      ref.read(storiesControllerProvider)?.templateOf(s.template) ??
      StoryTemplate(type: s.template);

  bool _waiting(Story s, StoryTemplate t) =>
      t.interactive && s.isQuestion && s.answeredChoice == null;

  /// A new segment is on screen: mark it seen, start (or hold) the timer.
  void _begin() {
    if (!mounted) return;
    final story = _current();
    final tpl = _templateOf(story);
    unawaited(ref.read(storiesControllerProvider.notifier).markSeen(story.key));
    _timer.stop();
    _timer.value = 0;
    if (_waiting(story, tpl)) return;
    _timer.duration = Duration(milliseconds: tpl.durationMs);
    if (!_holding) _timer.forward(from: 0);
  }

  void _afterAnswer() {
    if (!mounted) return;
    final tpl = _templateOf(_current());
    _timer.duration = Duration(milliseconds: tpl.durationMs);
    if (!_holding) _timer.forward(from: 0);
  }

  void _setHolding(bool hold) {
    _holding = hold;
    if (hold) {
      _timer.stop();
    } else {
      final story = _current();
      if (!_waiting(story, _templateOf(story)) &&
          _timer.status != AnimationStatus.completed) {
        _timer.forward();
      }
    }
  }

  Duration get _pageMotion =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : KMotion.normal;

  void _next() {
    if (!mounted) return;
    final count = _groups[_group].stories.length;
    if (_seg < count - 1) {
      setState(() => _segment[_group] = _seg + 1);
      _begin();
    } else if (_group < _groups.length - 1) {
      _pages.nextPage(duration: _pageMotion, curve: KMotion.curve);
    } else {
      _close();
    }
  }

  void _prev() {
    if (_seg > 0) {
      setState(() => _segment[_group] = _seg - 1);
      _begin();
    } else if (_group > 0) {
      _pages.previousPage(duration: _pageMotion, curve: KMotion.curve);
    } else {
      _begin();
    }
  }

  void _onPage(int i) {
    setState(() {
      _group = i;
      _segment[i] = _firstUnseen(i);
    });
    _begin();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _go(String path) {
    final router = GoRouter.of(context);
    _close();
    router.push(path);
  }

  void _onTap(double dx, double width, bool rtl) {
    final startSide = dx < width / 3;
    final endSide = dx > width * 2 / 3;
    if (rtl ? endSide : startSide) {
      _prev();
    } else {
      _next();
    }
  }

  Future<void> _share(int streak) async {
    final l10n = AppLocalizations.of(context);
    final text = shareMessage(l10n.storyStreakShare(streak));
    final messenger = ScaffoldMessenger.of(context);
    _setHolding(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in shareTargets(text))
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                onTap: () async {
                  Navigator.of(sheet).pop();
                  await launchUrl(t.uri, mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l10n.shareCopy),
              onTap: () async {
                Navigator.of(sheet).pop();
                await Clipboard.setData(ClipboardData(text: text));
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.shareCopied)),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (mounted) _setHolding(false);
  }

  void _showCoins(int coins) {
    setState(() {
      _flyCoins = coins;
      _flyId++;
    });
  }

  Widget _body(Story story, StoryTemplate tpl) {
    if (story.isQuestion) {
      return QuestionStoryView(
        key: ValueKey<String>(story.key),
        story: story,
        template: tpl,
        onAnswered: _afterAnswer,
        onCoins: _showCoins,
        onGo: _go,
      );
    }
    return switch (story.template) {
      'plan' => PlanStoryView(
        key: ValueKey<String>(story.key),
        story: story,
        template: tpl,
        onGo: _go,
      ),
      'streak' => StreakStoryView(
        key: ValueKey<String>(story.key),
        story: story,
        template: tpl,
        onShare: _share,
      ),
      _ => GenericStoryView(
        key: ValueKey<String>(story.key),
        story: story,
        template: tpl,
      ),
    };
  }

  Widget _page(BuildContext context, int gi, StoriesData? data) {
    final group = _groups[gi];
    final seg = (_segment[gi] ?? 0).clamp(0, group.stories.length - 1);
    final story = _latest(group.stories[seg], data);
    final tpl =
        data?.templateOf(story.template) ?? StoryTemplate(type: story.template);
    final lang = Localizations.localeOf(context).languageCode;
    final name = localized(tpl.name, lang);
    final module = localized(asMap(story.payload['module'])['name_i18n'], lang);
    final title = module.isEmpty ? name : '$name - $module';
    return ColoredBox(
      color: tpl.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.md,
            KSpace.sm,
            KSpace.md,
            KSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Segments(
                count: group.stories.length,
                current: seg,
                active: gi == _group,
                timer: _timer,
                fg: tpl.fg,
              ),
              const SizedBox(height: KSpace.sm),
              _Header(
                title: title,
                icon: storyIcon(tpl.icon),
                tpl: tpl,
                onClose: _close,
              ),
              const SizedBox(height: KSpace.lg),
              Expanded(child: _body(story, tpl)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storiesControllerProvider);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(
              d.localPosition.dx,
              MediaQuery.sizeOf(context).width,
              rtl,
            ),
            onLongPressStart: (_) => _setHolding(true),
            onLongPressEnd: (_) => _setHolding(false),
            onLongPressCancel: () => _setHolding(false),
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) _close();
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: _groups.length,
              onPageChanged: _onPage,
              itemBuilder: (context, gi) => _page(context, gi, data),
            ),
          ),
          if (_flyCoins != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _CoinFly(
                  key: ValueKey<int>(_flyId),
                  amount: _flyCoins!,
                  reduce: reduce,
                  onDone: () {
                    if (mounted) setState(() => _flyCoins = null);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.count,
    required this.current,
    required this.active,
    required this.timer,
    required this.fg,
  });

  final int count;
  final int current;
  final bool active;
  final Animation<double> timer;
  final Color fg;

  Widget _bar(double value) => LinearProgressIndicator(
    value: value,
    minHeight: 3,
    backgroundColor: fg.withValues(alpha: 0.3),
    valueColor: AlwaysStoppedAnimation<Color>(fg),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: i == count - 1 ? 0 : 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: i == current && active
                    ? AnimatedBuilder(
                        animation: timer,
                        builder: (context, _) => _bar(timer.value),
                      )
                    : _bar(i < current ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.title,
    required this.icon,
    required this.tpl,
    required this.onClose,
  });

  final String title;
  final IconData icon;
  final StoryTemplate tpl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletControllerProvider);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tpl.fg.withValues(alpha: 0.2),
          ),
          child: Icon(icon, color: tpl.fg, size: 20),
        ),
        const SizedBox(width: KSpace.sm),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tpl.fg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (wallet != null) ...[
          Icon(Icons.monetization_on_rounded, color: tpl.accent, size: 20),
          const SizedBox(width: KSpace.xs),
          Text(
            '${wallet.balance}',
            style: TextStyle(color: tpl.fg, fontWeight: FontWeight.w800),
          ),
        ],
        IconButton(
          tooltip: l10n.storiesClose,
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: tpl.fg),
        ),
      ],
    );
  }
}

/// "+10" flies from the answers to the counter (reduce motion: it just
/// appears next to the counter and fades).
class _CoinFly extends StatefulWidget {
  const _CoinFly({
    super.key,
    required this.amount,
    required this.reduce,
    required this.onDone,
  });

  final int amount;
  final bool reduce;
  final VoidCallback onDone;

  @override
  State<_CoinFly> createState() => _CoinFlyState();
}

class _CoinFlyState extends State<_CoinFly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduce ? 1200 : 900),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = widget.reduce ? 1.0 : Curves.easeInOut.transform(_c.value);
        final alignment = AlignmentDirectional.lerp(
          const AlignmentDirectional(0, 0.35),
          const AlignmentDirectional(0.75, -0.9),
          t,
        )!;
        final fade = widget.reduce
            ? (_c.value < 0.7 ? 1.0 : (1 - _c.value) / 0.3)
            : (t < 0.85 ? 1.0 : (1 - t) / 0.15);
        return Align(
          alignment: alignment,
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.md,
                vertical: KSpace.xs + 2,
              ),
              decoration: BoxDecoration(
                color: kc.xp,
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: KSpace.xs),
                  Text(
                    '+${widget.amount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
