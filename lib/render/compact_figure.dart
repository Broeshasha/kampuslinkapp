import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/logging/logger.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/lessons/figures.dart';
import '../l10n/app_localizations.dart';
import 'figure_block.dart';

final _logged = <int>{};

void _logOnce(String svg, String why) {
  if (_logged.add(svg.hashCode)) {
    appLog.warn('figure: $why, shown as "diagram unavailable"');
  }
}

/// Opens [figure] full screen (pinch / double-tap to zoom).
void openFigureZoom(
  BuildContext context,
  Map<String, dynamic> figure,
  String language,
) {
  final asset = figure['asset'];
  final raw = asset is Map ? '${asset['svg'] ?? ''}' : '';
  if (!isSafeSvg(raw)) return;
  final kc = context.kc;
  final caption = figureText(figure['caption'], language);
  final alt = asset is Map ? figureText(asset['alt'], language) : '';
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FigureZoomPage(
        title: caption,
        child: SvgPicture.string(
          themeSvg(raw, kc),
          fit: BoxFit.contain,
          semanticsLabel: alt.isNotEmpty ? alt : caption,
        ),
      ),
    ),
  );
}

/// A small themed diagram for cards, questions, options and carousel
/// covers: fixed [height], shimmer while the SVG is parsed, tap to zoom
/// (or a zoom button when the tap belongs to the parent, e.g. an option),
/// alt text for screen readers, and a "diagram unavailable" chip (logged)
/// when the SVG is unsafe or broken.
class CompactFigure extends StatelessWidget {
  const CompactFigure({
    super.key,
    required this.figure,
    required this.language,
    this.height = 180,
    this.showCaption = true,
    this.zoomButton = false,
  });

  final Map<String, dynamic> figure;
  final String language;
  final double height;
  final bool showCaption;

  /// true = a small zoom button instead of tap-anywhere (the tap selects).
  final bool zoomButton;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final asset = figure['asset'];
    final a = asset is Map
        ? asset.cast<String, dynamic>()
        : const <String, dynamic>{};
    final raw = a['type'] == null || a['type'] == 'svg'
        ? '${a['svg'] ?? ''}'
        : '';
    if (!isSafeSvg(raw)) {
      _logOnce(raw, 'unsafe or empty svg');
      return const DiagramUnavailable();
    }
    final caption = figureText(figure['caption'], language);
    final altText = figureText(a['alt'], language);
    final alt = altText.isNotEmpty ? altText : caption;
    final picture = SizedBox(
      height: height,
      width: double.infinity,
      child: SvgPicture.string(
        themeSvg(raw, kc),
        fit: BoxFit.contain,
        semanticsLabel: alt.isEmpty ? null : alt,
        placeholderBuilder: (_) => const FigureShimmer(),
        errorBuilder: (context, error, stack) {
          _logOnce(raw, 'broken svg ($error)');
          return const DiagramUnavailable();
        },
      ),
    );
    final Widget visual;
    if (zoomButton) {
      visual = Stack(
        children: [
          picture,
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Material(
              color: kc.surfaceRaised.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: AppLocalizations.of(context).zoomFigure,
                onPressed: () => openFigureZoom(context, figure, language),
                icon: Icon(Icons.zoom_out_map_rounded, color: kc.textPrimary),
              ),
            ),
          ),
        ],
      );
    } else {
      visual = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openFigureZoom(context, figure, language),
        child: picture,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        visual,
        if (showCaption && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.xs),
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// Small chip shown instead of a figure that cannot be drawn.
class DiagramUnavailable extends StatelessWidget {
  const DiagramUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.sm,
          vertical: KSpace.xs,
        ),
        decoration: BoxDecoration(
          color: kc.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 16,
              color: kc.textSecondary,
            ),
            const SizedBox(width: KSpace.xs),
            Flexible(
              child: Text(
                AppLocalizations.of(context).diagramUnavailable,
                style: TextStyle(color: kc.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft pulsing box while an SVG is parsed (still when motion is reduced).
class FigureShimmer extends StatefulWidget {
  const FigureShimmer({super.key});

  @override
  State<FigureShimmer> createState() => _FigureShimmerState();
}

class _FigureShimmerState extends State<FigureShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: kc.surfaceRaised.withValues(alpha: 0.4 + 0.4 * _c.value),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Answer options: one column; with option figures, 2 columns (2x2), or one
/// column again on narrow phones (under 340 px wide).
class OptionGrid extends StatelessWidget {
  const OptionGrid({
    super.key,
    required this.count,
    required this.withFigures,
    required this.itemBuilder,
  });

  final int count;
  final bool withFigures;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (!withFigures) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: itemBuilder(context, i),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth < 340 ? 1 : 2;
        final w = (box.maxWidth - KSpace.sm * (cols - 1)) / cols;
        return Padding(
          padding: const EdgeInsets.only(bottom: KSpace.sm),
          child: Wrap(
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(width: w, child: itemBuilder(context, i)),
            ],
          ),
        );
      },
    );
  }
}
