import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/logging/logger.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'block_style.dart';

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
String _text(Object? v) => v == null ? '' : '$v';
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// CONTENT_FORMAT 5.5 author rules: viewBox, no scripts, no foreignObject,
/// no event handlers, no external links, under 200 KB.
bool isSafeSvg(String svg) {
  final lower = svg.toLowerCase();
  return svg.isNotEmpty &&
      svg.length <= 200 * 1024 &&
      lower.contains('viewbox') &&
      !lower.contains('<script') &&
      !lower.contains('foreignobject') &&
      !RegExp(r'\son[a-z]+\s*=').hasMatch(lower) &&
      !RegExp(r'href\s*=\s*["\x27](https?:|//)').hasMatch(lower);
}

/// {{c1}}..{{c6}}: categorical palette (blue, violet, teal, amber, rose,
/// green), each >= 3:1 on the figure background of its theme.
const svgPaletteLight = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFFBE185D),
  Color(0xFF15803D),
];
const svgPaletteDark = [
  Color(0xFF60A5FA),
  Color(0xFFA78BFA),
  Color(0xFF2DD4BF),
  Color(0xFFFBBF24),
  Color(0xFFF472B6),
  Color(0xFF4ADE80),
];

bool _isDark(KampusColors kc) => kc.background.computeLuminance() < 0.5;

List<Color> svgPalette(KampusColors kc) =>
    _isDark(kc) ? svgPaletteDark : svgPaletteLight;

final _placeholder = RegExp(r'\{\{([A-Za-z0-9_]+)\}\}');
final _loggedPlaceholders = <String>{};

/// Replaces the theme placeholders so drawings follow light/dark. An
/// unknown placeholder is drawn as {{fg}} and logged once.
String themeSvg(String svg, KampusColors kc) {
  final palette = svgPalette(kc);
  final colours = <String, Color>{
    'fg': kc.textPrimary,
    'muted': kc.textSecondary,
    'accent': kc.accent,
    'bg': kc.surfaceRaised,
    'ok': kc.success,
    'warn': kc.warning,
    for (var i = 0; i < palette.length; i++) 'c${i + 1}': palette[i],
  };
  return svg.replaceAllMapped(_placeholder, (m) {
    final name = m.group(1) ?? '';
    final colour = colours[name];
    if (colour != null) return _hex(colour);
    if (_loggedPlaceholders.add(name)) {
      appLog.warn('svg: unknown placeholder {{$name}} drawn as {{fg}}');
    }
    return _hex(kc.textPrimary);
  });
}

/// Full-screen figure: pinch to zoom, double-tap to zoom in / back out.
class FigureZoomPage extends StatefulWidget {
  const FigureZoomPage({super.key, required this.child, this.title = ''});

  final Widget child;
  final String title;

  @override
  State<FigureZoomPage> createState() => _FigureZoomPageState();
}

class _FigureZoomPageState extends State<FigureZoomPage> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    const zoom = 2.5;
    _transform.value = Matrix4.diagonal3Values(zoom, zoom, 1)
      ..setTranslationRaw(-_tap.dx * (zoom - 1), -_tap.dy * (zoom - 1), 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: GestureDetector(
          onDoubleTapDown: (d) => _tap = d.localPosition,
          onDoubleTap: _doubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 6,
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(KSpace.lg),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A figure: themed SVG / image when present (tap to zoom), otherwise a
/// "Diagram" card with caption, labels and an expandable description.
/// The card is a Material so the description tile's ripple shows.
class FigureBlock extends StatelessWidget {
  const FigureBlock({super.key, required this.block, required this.style});

  final Map<String, dynamic> block;
  final BlockStyle style;

  void _zoom(BuildContext context, Widget child, String title) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => FigureZoomPage(title: title, child: child),
        ),
      );

  Widget? _visual(BuildContext context, String caption) {
    final kc = style.kc;
    final asset = _map(block['asset']);
    final type = _text(asset['type']);
    if (type == 'svg') {
      final raw = _text(asset['svg']);
      if (!isSafeSvg(raw)) {
        appLog.warn('figure ${block['id']}: unsafe or empty svg skipped');
        return null;
      }
      final svg = themeSvg(raw, kc);
      final alt = _text(asset['alt']).isNotEmpty
          ? _text(asset['alt'])
          : caption;
      return GestureDetector(
        onTap: () => _zoom(
          context,
          SvgPicture.string(svg, fit: BoxFit.contain, semanticsLabel: alt),
          caption,
        ),
        child: SvgPicture.string(
          svg,
          height: 180 * style.scale,
          semanticsLabel: alt,
        ),
      );
    }
    if (type == 'image') {
      final url = _text(asset['url'] ?? asset['path']);
      if (url.startsWith('http')) {
        return GestureDetector(
          onTap: () => _zoom(
            context,
            Image.network(url, fit: BoxFit.contain, semanticLabel: caption),
            caption,
          ),
          child: Image.network(
            url,
            height: 200 * style.scale,
            fit: BoxFit.contain,
            semanticLabel: caption,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    final number = block['figure_number'];
    final caption = _text(block['caption']);
    final description = _text(block['description']);
    final labels = _list(block['labels']).map(_map).toList();
    final visual = _visual(context, caption);
    return Material(
      color: kc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: kc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schema_outlined, color: kc.accentText, size: 20),
                const SizedBox(width: KSpace.sm),
                Text(
                  number is num
                      ? style.labels.figureLabel(number.toInt())
                      : style.labels.blockDiagram,
                  style: TextStyle(
                    color: kc.accentText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * style.scale,
                  ),
                ),
              ],
            ),
            if (visual != null) ...[
              const SizedBox(height: KSpace.sm),
              Center(child: visual),
            ],
            if (caption.isNotEmpty) ...[
              const SizedBox(height: KSpace.sm),
              Text(
                caption,
                style: style.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (labels.isNotEmpty) ...[
              const SizedBox(height: KSpace.sm),
              Wrap(
                spacing: KSpace.sm,
                runSpacing: KSpace.xs,
                children: [
                  for (final l in labels)
                    _LabelChip(
                      text: _text(l['text']),
                      translation: _text(l['translation']),
                      style: style,
                    ),
                ],
              ),
            ],
            if (description.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: KSpace.sm),
                  title: Text(
                    style.labels.blockDescription,
                    style: TextStyle(
                      color: kc.textSecondary,
                      fontSize: 14 * style.scale,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(description, style: style.body),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.text,
    required this.translation,
    required this.style,
  });

  final String text;
  final String translation;
  final BlockStyle style;

  @override
  Widget build(BuildContext context) {
    final kc = style.kc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: kc.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          text: style.ltr(text),
          style: TextStyle(
            color: kc.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13 * style.scale,
          ),
          children: [
            if (translation.isNotEmpty)
              TextSpan(
                text: ' \u00b7 $translation',
                style: TextStyle(
                  color: kc.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
