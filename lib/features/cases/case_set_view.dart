import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/rich_block_text.dart';
import 'case_models.dart';

/// A carousel set inside the vertical feed (lead brief B3): the horizontal
/// pager owns horizontal drags, a vertical swipe moves to the next post.
/// In Arabic the pager follows the reading direction (swipe the other way).
/// The "commit" slide must be answered (guess locked) before the reveal.
class CaseSetView extends StatefulWidget {
  const CaseSetView({
    super.key,
    required this.set,
    required this.progress,
    required this.onProgress,
    this.demo = false,
  });

  final CaseSet set;
  final CaseProgress progress;
  final ValueChanged<CaseProgress> onProgress;
  final bool demo;

  @override
  State<CaseSetView> createState() => _CaseSetViewState();
}

class _CaseSetViewState extends State<CaseSetView> {
  late CaseProgress _p = widget.progress;
  late final PageController _pages;
  late int _page;
  int? _choice;
  bool _needGuess = false;

  CaseSet get _set => widget.set;
  int get _commit => _set.commitIndex;
  int get _last => _set.slides.length - 1;

  @override
  void initState() {
    super.initState();
    var start = _p.reached.clamp(0, math.max(0, _last));
    if (_commit >= 0 && _p.guess == null && start > _commit) start = _commit;
    _page = start.toInt();
    _choice = _p.guess;
    _pages = PageController(initialPage: start.toInt());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _save(CaseProgress p) {
    _p = p;
    widget.onProgress(p);
  }

  void _onPage(int i) {
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
    HapticFeedback.lightImpact();
    setState(() => _needGuess = false);
    _save(_p.copyWith(guess: choice));
    _pages.nextPage(duration: KMotion.slow, curve: KMotion.curve);
  }

  void _answer(CaseSlide s, int i) {
    if (_p.answers.containsKey(s.id)) return;
    HapticFeedback.selectionClick();
    setState(() {});
    _save(_p.copyWith(answers: {..._p.answers, s.id: i}));
  }

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
    final accent = kc.accentAlt;
    return Directionality(
      textDirection: style.direction,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpace.lg,
          KSpace.sm,
          KSpace.lg,
          KSpace.lg,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.sheet),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.22), kc.surface],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.lg,
                  KSpace.md,
                  KSpace.lg,
                  0,
                ),
                child: Row(
                  children: [
                    _Chip(text: l10n.caseLabel, color: accent),
                    if (widget.demo) ...[
                      const SizedBox(width: KSpace.xs),
                      _Chip(text: l10n.demoBadge, color: kc.warning),
                    ],
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Text(
                        _set.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_page + 1}/${_set.slides.length}',
                      style: TextStyle(color: kc.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  onPageChanged: _onPage,
                  itemCount: _set.slides.length,
                  itemBuilder: (context, i) => _SlideBody(
                    key: ValueKey<String>(_set.slides[i].id),
                    slide: _set.slides[i],
                    style: style,
                    accent: accent,
                    choice: _choice,
                    progress: _p,
                    commitSlide: _set.commitSlide,
                    onChoose: (c) => setState(() => _choice = c),
                    onLock: _lock,
                    onAnswer: (c) => _answer(_set.slides[i], c),
                  ),
                ),
              ),
              if (_needGuess)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpace.xs),
                  child: Text(
                    l10n.lockGuessFirst,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kc.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.md),
                child: _Dots(
                  count: _set.slides.length,
                  index: _page,
                  color: accent,
                ),
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

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: KMotion.fast,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: i == index ? color : color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({
    super.key,
    required this.slide,
    required this.style,
    required this.accent,
    required this.choice,
    required this.progress,
    required this.commitSlide,
    required this.onChoose,
    required this.onLock,
    required this.onAnswer,
  });

  final CaseSlide slide;
  final BlockStyle style;
  final Color accent;
  final int? choice;
  final CaseProgress progress;
  final CaseSlide? commitSlide;
  final ValueChanged<int> onChoose;
  final VoidCallback onLock;
  final ValueChanged<int> onAnswer;

  String _roleLabel(AppLocalizations l10n) => switch (slide.role) {
    SlideRole.hook => l10n.roleHook,
    SlideRole.clue => l10n.roleClue,
    SlideRole.step => l10n.roleStep,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final children = <Widget>[
      Row(
        children: [
          Icon(_icon, size: 18, color: accent),
          const SizedBox(width: KSpace.xs),
          Text(
            _roleLabel(l10n).toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
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
    switch (slide.role) {
      case SlideRole.commit:
        final locked = progress.guess != null;
        children.addAll([
          _Prompt(text: slide.prompt, style: style),
          for (var i = 0; i < slide.options.length; i++)
            _Option(
              text: slide.options[i],
              style: style,
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
          children.insert(
            2,
            Container(
              margin: const EdgeInsets.only(bottom: KSpace.md),
              padding: const EdgeInsets.all(KSpace.md),
              decoration: BoxDecoration(
                color: (right ? kc.success : kc.danger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Text(
                right ? l10n.guessRight : l10n.guessWrong,
                style: TextStyle(
                  color: right ? kc.success : kc.danger,
                  fontWeight: FontWeight.w800,
                ),
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
      case SlideRole.takeaway:
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: KSpace.lg),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: kc.success),
                const SizedBox(width: KSpace.sm),
                Text(
                  l10n.caseDone,
                  style: TextStyle(
                    color: kc.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        break;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
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
  });

  final String text;
  final BlockStyle style;
  final bool selected;
  final _OptState state;
  final Color accent;
  final VoidCallback? onTap;

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
          borderRadius: BorderRadius.circular(KRadius.chip),
          side: BorderSide(color: color, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpace.md),
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
