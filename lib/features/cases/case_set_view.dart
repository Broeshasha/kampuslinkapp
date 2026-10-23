import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/figure_block.dart';
import '../../render/rich_block_text.dart';
import '../../ui/confetti.dart';
import 'case_models.dart';

/// A carousel set (lead brief 2, D), Stories-like in our colours:
/// segmented progress bar, kind badge, "2/6", a kebab to report a mistake
/// on every slide. The horizontal pager owns horizontal drags; a vertical
/// drag goes to the parent feed (next post). In Arabic everything is
/// mirrored. The commit slide must be locked before the reveal (the pager
/// bounces back with a shake and a hint). Progress is saved at every step.
class CaseSetView extends StatefulWidget {
  const CaseSetView({
    super.key,
    required this.set,
    required this.progress,
    required this.onProgress,
    this.demo = false,
    this.accent,
    this.showSwipeHint = false,
    this.onHintSeen,
    this.onNext,
    this.onReport,
    this.badge,
  });

  final CaseSet set;
  final CaseProgress progress;
  final ValueChanged<CaseProgress> onProgress;
  final bool demo;
  final Color? accent;

  /// First time only: an animated "swipe" hint on the first slide.
  final bool showSwipeHint;
  final VoidCallback? onHintSeen;

  /// "Next case" on the takeaway slide.
  final VoidCallback? onNext;

  /// "Report a mistake" for the slide id.
  final ValueChanged<String>? onReport;

  /// An extra label next to the kind (e.g. DRAFT in the admin preview).
  final String? badge;

  @override
  State<CaseSetView> createState() => _CaseSetViewState();
}

class _CaseSetViewState extends State<CaseSetView>
    with SingleTickerProviderStateMixin {
  late CaseProgress _p = widget.progress;
  late final PageController _pages;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late int _page;
  int? _choice;
  bool _needGuess = false;
  late bool _hint = widget.showSwipeHint;

  CaseSet get _set => widget.set;
  int get _commit => _set.commitIndex;
  int get _last => _set.slides.length - 1;

  @override
  void initState() {
    super.initState();
    var start = math.min(math.max(_p.reached, 0), math.max(0, _last));
    if (_commit >= 0 && _p.guess == null && start > _commit) start = _commit;
    _page = start;
    _choice = _p.guess;
    _pages = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pages.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _save(CaseProgress p) {
    _p = p;
    widget.onProgress(p);
  }

  void _onPage(int i) {
    if (_hint) {
      _hint = false;
      widget.onHintSeen?.call();
    }
    if (_commit >= 0 && _p.guess == null && i > _commit) {
      setState(() => _needGuess = true);
      HapticFeedback.mediumImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) {
          _pages.animateToPage(
            _commit,
            duration: KMotion.normal,
            curve: KMotion.curve,
          );
          if (!MediaQuery.disableAnimationsOf(context)) {
            _shake.forward(from: 0);
          }
        }
      });
      return;
    }
    // The bounce back to the commit slide keeps the hint visible.
    setState(() {
      _page = i;
      _needGuess = _needGuess && i == _commit;
    });
    _save(
      _p.copyWith(
        reached: math.max(_p.reached, i),
        finished: _p.finished || i == _last,
      ),
    );
  }

  void _lock() {
    final choice = _choice;
    if (choice == null) return;
    HapticFeedback.heavyImpact();
    setState(() => _needGuess = false);
    final correctIndex = _set.commitSlide?.correctIndex;
    _save(
      _p.copyWith(
        guess: choice,
        correct: correctIndex == null ? null : choice == correctIndex,
      ),
    );
    _pages.nextPage(duration: KMotion.slow, curve: KMotion.curve);
  }

  void _answer(CaseSlide s, int i) {
    if (_p.answers.containsKey(s.id)) return;
    HapticFeedback.selectionClick();
    setState(() {});
    _save(_p.copyWith(answers: {..._p.answers, s.id: i}));
    // Quiz chains move on by themselves after each answer.
    if (_set.kind == CaseKind.quizChain && _page < _last) {
      Timer(const Duration(milliseconds: 1100), () {
        if (mounted && _pages.hasClients) {
          _pages.nextPage(duration: KMotion.slow, curve: KMotion.curve);
        }
      });
    }
  }

  void _toggleSave() {
    HapticFeedback.selectionClick();
    setState(() {});
    _save(_p.copyWith(saved: !_p.saved));
  }

  String _kindLabel(AppLocalizations l10n) => switch (_set.kind) {
    CaseKind.mystery => l10n.kindMystery,
    CaseKind.explainer => l10n.kindExplainer,
    CaseKind.quizChain => l10n.kindQuizChain,
    CaseKind.other => l10n.caseLabel,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = supportedLanguageCodes.contains(_set.language)
        ? _set.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: 1.15,
      kc: kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    final accent = widget.accent ?? kc.accentAlt;
    final count = _set.slides.length;
    return Directionality(
      textDirection: style.direction,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpace.md,
          KSpace.xs,
          KSpace.md,
          KSpace.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.sheet),
            color: kc.surface,
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.sheet),
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KSpace.md,
                        KSpace.md,
                        KSpace.md,
                        0,
                      ),
                      child: _Segments(
                        count: count,
                        index: _page,
                        color: accent,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        KSpace.lg,
                        KSpace.sm,
                        KSpace.xs,
                        0,
                      ),
                      child: Row(
                        children: [
                          _Chip(text: _kindLabel(l10n), color: accent),
                          if (widget.demo) ...[
                            const SizedBox(width: KSpace.xs),
                            _Chip(text: l10n.demoBadge, color: kc.warning),
                          ],
                          if (widget.badge case final badge?) ...[
                            const SizedBox(width: KSpace.xs),
                            _Chip(text: badge, color: kc.warning),
                          ],
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: Text(
                              _set.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_page + 1}/$count',
                            style: TextStyle(color: kc.textSecondary),
                          ),
                          if (widget.onReport != null)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: kc.textSecondary,
                              ),
                              onSelected: (_) =>
                                  widget.onReport?.call(_set.slides[_page].id),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(l10n.reportMistake),
                                ),
                              ],
                            )
                          else
                            const SizedBox(width: KSpace.md),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        onPageChanged: _onPage,
                        itemCount: count,
                        itemBuilder: (context, i) {
                          final slide = _set.slides[i];
                          var n = 0;
                          var total = 0;
                          for (var j = 0; j < count; j++) {
                            if (_set.slides[j].role != slide.role) continue;
                            total++;
                            if (j <= i) n++;
                          }
                          final body = _SlideBody(
                            key: ValueKey<String>(slide.id),
                            slide: slide,
                            roleIndex: n,
                            roleTotal: total,
                            active: i == _page,
                            style: style,
                            accent: accent,
                            choice: _choice,
                            progress: _p,
                            commitSlide: _set.commitSlide,
                            onChoose: (c) => setState(() => _choice = c),
                            onLock: _lock,
                            onAnswer: (c) => _answer(slide, c),
                            onSave: _toggleSave,
                            onNext: widget.onNext,
                            onReport: widget.onReport == null
                                ? null
                                : () => widget.onReport!(slide.id),
                          );
                          if (slide.role != SlideRole.commit) return body;
                          return AnimatedBuilder(
                            animation: _shake,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                math.sin(_shake.value * math.pi * 6) *
                                    10 *
                                    (1 - _shake.value),
                                0,
                              ),
                              child: child,
                            ),
                            child: body,
                          );
                        },
                      ),
                    ),
                    if (_needGuess)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KSpace.lg,
                          0,
                          KSpace.lg,
                          KSpace.md,
                        ),
                        child: Text(
                          l10n.lockGuessFirst,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kc.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_hint && _page == 0 && count > 1)
                  const PositionedDirectional(
                    end: KSpace.lg,
                    bottom: KSpace.lg,
                    child: IgnorePointer(child: _SwipeHint()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per slide; filled up to the current one (mirrored in RTL).
class _Segments extends StatelessWidget {
  const _Segments({
    required this.count,
    required this.index,
    required this.color,
  });

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Expanded(
          child: AnimatedContainer(
            duration: KMotion.normal,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i <= index ? color : color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
    ],
  );
}

/// "Swipe" with an arrow sliding toward the next slide (towards the
/// start side, so it follows RTL); still when the phone reduces motion.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final l10n = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.translate(
        offset: Offset((rtl ? 1 : -1) * 14 * _c.value, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: KSpace.sm,
          ),
          decoration: BoxDecoration(
            color: kc.surfaceRaised.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(KRadius.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                size: 18,
                color: kc.textPrimary,
              ),
              const SizedBox(width: KSpace.xs),
              Text(
                l10n.swipeForMore,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(KRadius.chip),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({
    super.key,
    required this.slide,
    required this.roleIndex,
    required this.roleTotal,
    required this.active,
    required this.style,
    required this.accent,
    required this.choice,
    required this.progress,
    required this.commitSlide,
    required this.onChoose,
    required this.onLock,
    required this.onAnswer,
    required this.onSave,
    this.onNext,
    this.onReport,
  });

  final CaseSlide slide;
  final int roleIndex;
  final int roleTotal;
  final bool active;
  final BlockStyle style;
  final Color accent;
  final int? choice;
  final CaseProgress progress;
  final CaseSlide? commitSlide;
  final ValueChanged<int> onChoose;
  final VoidCallback onLock;
  final ValueChanged<int> onAnswer;
  final VoidCallback onSave;
  final VoidCallback? onNext;
  final VoidCallback? onReport;

  String _roleLabel(AppLocalizations l10n) => switch (slide.role) {
    SlideRole.hook => l10n.roleHook,
    SlideRole.clue =>
      roleTotal > 1 ? l10n.clueCount(roleIndex, roleTotal) : l10n.roleClue,
    SlideRole.step =>
      roleTotal > 1 ? l10n.stepCount(roleIndex, roleTotal) : l10n.roleStep,
    SlideRole.commit => l10n.roleCommit,
    SlideRole.reveal => l10n.roleReveal,
    SlideRole.quiz => l10n.roleQuiz,
    SlideRole.takeaway || SlideRole.unknown => l10n.roleTakeaway,
  };

  IconData get _icon => switch (slide.role) {
    SlideRole.hook => Icons.search_rounded,
    SlideRole.clue => Icons.lightbulb_outline_rounded,
    SlideRole.step => Icons.format_list_numbered_rounded,
    SlideRole.commit => Icons.how_to_vote_outlined,
    SlideRole.reveal => Icons.visibility_outlined,
    SlideRole.quiz => Icons.quiz_outlined,
    _ => Icons.push_pin_outlined,
  };

  Widget _label(AppLocalizations l10n, Color color) => Row(
    children: [
      Icon(_icon, size: 18, color: color),
      const SizedBox(width: KSpace.xs),
      Flexible(
        child: Text(
          _roleLabel(l10n).toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    ],
  );

  Widget _hook(BuildContext context, AppLocalizations l10n) {
    final kc = context.kc;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [accent.withValues(alpha: 0.55), kc.background],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -10,
            bottom: -40,
            child: ExcludeSemantics(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 220,
                  fontWeight: FontWeight.w900,
                  color: kc.textPrimary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(KSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(l10n, kc.textPrimary),
                const SizedBox(height: KSpace.lg),
                if (slide.title.isNotEmpty)
                  Text(
                    slide.title,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                const SizedBox(height: KSpace.md),
                if (slide.content.isNotEmpty)
                  RichBlockText(
                    text: slide.content,
                    highlights: slide.highlights,
                    style: BlockStyle(
                      language: style.language,
                      scale: style.scale * 1.25,
                      kc: style.kc,
                      labels: style.labels,
                      base: style.base.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    if (slide.role == SlideRole.hook) return _hook(context, l10n);
    final still = MediaQuery.disableAnimationsOf(context);
    final children = <Widget>[
      _label(l10n, accent),
      const SizedBox(height: KSpace.md),
    ];
    if (slide.title.isNotEmpty) {
      children.add(
        Text(
          slide.title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      );
      children.add(const SizedBox(height: KSpace.md));
    }
    if (slide.content.isNotEmpty) {
      children.add(
        RichBlockText(
          text: slide.content,
          highlights: slide.highlights,
          style: style,
        ),
      );
    }
    final figure = slide.figure;
    if (figure != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: KSpace.md),
          child: FigureBlock(block: figure, style: style),
        ),
      );
    }
    var celebrate = false;
    switch (slide.role) {
      case SlideRole.commit:
        final locked = progress.guess != null;
        children.addAll([
          _Prompt(text: slide.prompt, style: style),
          for (var i = 0; i < slide.options.length; i++)
            _Option(
              text: slide.options[i],
              style: style,
              big: true,
              selected: (locked ? progress.guess : choice) == i,
              state: locked && progress.guess == i
                  ? _OptState.locked
                  : _OptState.idle,
              accent: accent,
              onTap: locked ? null : () => onChoose(i),
            ),
          const SizedBox(height: KSpace.sm),
          if (!locked)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: choice == null ? null : onLock,
              icon: const Icon(Icons.lock_rounded),
              label: Text(l10n.lockGuess),
            )
          else
            Text(
              l10n.swipeHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.textSecondary),
            ),
        ]);
      case SlideRole.reveal:
        final commit = commitSlide;
        final guess = progress.guess;
        if (commit != null && guess != null) {
          final right = guess == commit.correctIndex;
          celebrate = right && active;
          children.insert(
            2,
            Container(
              margin: const EdgeInsets.only(bottom: KSpace.md),
              padding: const EdgeInsets.all(KSpace.md),
              decoration: BoxDecoration(
                color: (right ? kc.success : kc.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Text(
                right ? l10n.guessRight : l10n.guessWrong,
                style: TextStyle(
                  color: right ? kc.success : kc.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }
        if (slide.explanation.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: KSpace.sm),
              child: RichBlockText(text: slide.explanation, style: style),
            ),
          );
        }
        if (slide.examNote.isNotEmpty) {
          children.add(
            Container(
              margin: const EdgeInsets.only(top: KSpace.md),
              padding: const EdgeInsets.all(KSpace.md),
              decoration: BoxDecoration(
                color: kc.xp.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.whyExam,
                    style: TextStyle(color: kc.xp, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: KSpace.xs),
                  RichBlockText(text: slide.examNote, style: style),
                ],
              ),
            ),
          );
        }
      case SlideRole.quiz:
        final answered = progress.answers[slide.id];
        children.add(_Prompt(text: slide.prompt, style: style));
        for (var i = 0; i < slide.options.length; i++) {
          children.add(
            _Option(
              text: slide.options[i],
              style: style,
              selected: answered == i,
              state: answered == null
                  ? _OptState.idle
                  : i == slide.correctIndex
                  ? _OptState.right
                  : i == answered
                  ? _OptState.wrong
                  : _OptState.idle,
              accent: accent,
              onTap: answered == null ? () => onAnswer(i) : null,
            ),
          );
        }
        if (answered != null && slide.explanation.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: KSpace.sm),
              child: RichBlockText(text: slide.explanation, style: style),
            ),
          );
        }
      case SlideRole.takeaway || SlideRole.unknown:
        children.addAll([
          Padding(
            padding: const EdgeInsets.only(top: KSpace.lg),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: kc.success),
                const SizedBox(width: KSpace.sm),
                Flexible(
                  child: Text(
                    l10n.caseDone,
                    style: TextStyle(
                      color: kc.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onSave,
                icon: Icon(
                  progress.saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                label: Text(progress.saved ? l10n.caseSaved : l10n.saveLabel),
              ),
              if (onNext != null)
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_downward_rounded),
                  label: Text(l10n.nextCase),
                ),
              if (onReport != null)
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(l10n.reportMistake),
                ),
            ],
          ),
        ]);
      default:
        break;
    }
    Widget body = SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (slide.role == SlideRole.reveal && !still) {
      // Blur-to-clear when the reveal comes on screen.
      body = TweenAnimationBuilder<double>(
        tween: Tween(end: active ? 0 : 8),
        duration: const Duration(milliseconds: 700),
        curve: KMotion.curve,
        builder: (context, sigma, child) => sigma < 0.05
            ? child!
            : ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              ),
        child: body,
      );
    }
    if (!celebrate) return body;
    return Stack(
      children: [
        body,
        const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.text, required this.style});

  final String text;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: KSpace.sm, bottom: KSpace.md),
    child: RichBlockText(
      text: text,
      style: BlockStyle(
        language: style.language,
        scale: style.scale * 1.1,
        kc: style.kc,
        labels: style.labels,
        base: style.base.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

enum _OptState { idle, locked, right, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.style,
    required this.selected,
    required this.state,
    required this.accent,
    required this.onTap,
    this.big = false,
  });

  final String text;
  final BlockStyle style;
  final bool selected;
  final _OptState state;
  final Color accent;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final color = switch (state) {
      _OptState.right => kc.success,
      _OptState.wrong => kc.danger,
      _ => selected ? accent : kc.border,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Material(
        color: selected || state != _OptState.idle
            ? color.withValues(alpha: 0.14)
            : kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.button),
          side: BorderSide(color: color, width: selected ? 2 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(big ? KSpace.lg : KSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: RichBlockText(text: text, style: style),
                ),
                if (state == _OptState.locked)
                  Icon(Icons.lock_rounded, size: 18, color: accent)
                else if (state == _OptState.right)
                  Icon(Icons.check_circle_rounded, color: kc.success)
                else if (state == _OptState.wrong)
                  Icon(Icons.cancel_rounded, color: kc.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
