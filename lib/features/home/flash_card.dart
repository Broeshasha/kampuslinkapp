import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/compact_figure.dart';
import '../../render/rich_block_text.dart';

/// One flashcard, reels style: tap = soft 3D flip; the back shows the
/// answer and "Again / I knew it"; like and save sit on the side.
class FlashCardView extends StatefulWidget {
  const FlashCardView({
    super.key,
    required this.front,
    required this.back,
    required this.language,
    required this.moduleName,
    required this.accent,
    required this.onAnswer,
    this.liked = false,
    this.saved = false,
    this.onLike,
    this.onSave,
    this.onReport,
    this.figure,
  });

  final String front;
  final String back;
  final String language;
  final String moduleName;
  final Color accent;
  final ValueChanged<bool> onAnswer;
  final bool liked;
  final bool saved;
  final ValueChanged<bool>? onLike;
  final ValueChanged<bool>? onSave;

  /// "Report a mistake" (flag under like / save).
  final VoidCallback? onReport;

  /// Optional diagram on top of both faces (max 45% of the text area).
  final Map<String, dynamic>? figure;

  @override
  State<FlashCardView> createState() => _FlashCardViewState();
}

class _FlashCardViewState extends State<FlashCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: KMotion.slow,
  );
  late bool _liked = widget.liked;
  late bool _saved = widget.saved;
  bool _answered = false;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_flip.status == AnimationStatus.completed ||
        _flip.status == AnimationStatus.forward) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  void _answer(bool knewIt) {
    if (_answered) return;
    _answered = true;
    HapticFeedback.lightImpact();
    widget.onAnswer(knewIt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = supportedLanguageCodes.contains(widget.language)
        ? widget.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: 1.25,
      kc: kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // TikTok style: like / save / report stacked on the card itself
    // (bottom end), so the card keeps the full width of the phone.
    final rail = _ActionRail(
      children: [
        _RailButton(
          icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: _liked ? kc.danger : kc.textPrimary,
          tooltip: l10n.likeLabel,
          onTap: () {
            setState(() => _liked = !_liked);
            widget.onLike?.call(_liked);
          },
        ),
        _RailButton(
          icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: _saved ? kc.xp : kc.textPrimary,
          tooltip: l10n.saveLabel,
          onTap: () {
            setState(() => _saved = !_saved);
            widget.onSave?.call(_saved);
          },
        ),
        if (widget.onReport case final report?)
          _RailButton(
            icon: Icons.flag_outlined,
            color: kc.textSecondary,
            tooltip: l10n.reportMistake,
            onTap: report,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.md,
        KSpace.xs,
        KSpace.md,
        KSpace.md,
      ),
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final t = reduceMotion
                ? (_flip.value < 0.5 ? 0.0 : 1.0)
                : Curves.easeInOutCubic.transform(_flip.value);
            final showBack = t >= 0.5;
            final angle = t * math.pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..multiply(
                  Matrix4.rotationY(showBack ? angle - math.pi : angle),
                ),
              child: _Face(
                key: ValueKey<bool>(showBack),
                accent: widget.accent,
                moduleName: widget.moduleName,
                back: showBack,
                text: showBack ? widget.back : widget.front,
                style: style,
                rail: rail,
                figure: widget.figure,
                footer: showBack
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _answer(false),
                              icon: const Icon(Icons.replay_rounded),
                              label: Text(l10n.again),
                            ),
                          ),
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: widget.accent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _answer(true),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l10n.knewIt),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        l10n.tapToFlip,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kc.textSecondary),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    super.key,
    required this.accent,
    required this.moduleName,
    required this.back,
    required this.text,
    required this.style,
    required this.footer,
    required this.rail,
    this.figure,
  });

  final Color accent;
  final String moduleName;
  final bool back;
  final String text;
  final BlockStyle style;
  final Widget footer;

  /// Like / save / report, stacked at the bottom end of the text area.
  final Widget rail;
  final Map<String, dynamic>? figure;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.sheet),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: back
              ? [kc.surfaceRaised, kc.surface]
              : [accent.withValues(alpha: 0.30), kc.surface],
        ),
        border: Border.all(color: accent.withValues(alpha: back ? 0.25 : 0.5)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Text(
                moduleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final fig = figure;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (fig != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: KSpace.sm),
                              child: CompactFigure(
                                figure: fig,
                                language: style.language,
                                height: box.maxHeight * 0.45,
                                showCaption: false,
                              ),
                            ),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsetsDirectional.only(
                                  end: _ActionRail.width,
                                ),
                                child: Directionality(
                                  textDirection: style.direction,
                                  child: RichBlockText(
                                    text: text,
                                    style: style,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                PositionedDirectional(end: 0, bottom: 0, child: rail),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          footer,
        ],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.children});

  /// Room kept free at the end of the card text for the rail.
  static const double width = 48;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: KSpace.sm),
        children[i],
      ],
    ],
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.kc.surfaceRaised.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 26,
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon, color: color),
      ),
    );
  }
}
