import 'package:flutter/material.dart';

/// Card text that fits the card (scaled down) so a vertical swipe always
/// moves the feed. Only text too long to stay readable (below [minScale])
/// scrolls inside the card.
class FitOrScroll extends StatefulWidget {
  const FitOrScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.minScale = 0.75,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minScale;

  @override
  State<FitOrScroll> createState() => _FitOrScrollState();
}

class _FitOrScrollState extends State<FitOrScroll> {
  final _key = GlobalKey();
  bool _scroll = false;

  void _measure(double available) {
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !mounted) return;
    final tooLong = box.size.height > available / widget.minScale;
    if (tooLong != _scroll) setState(() => _scroll = tooLong);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final content = Padding(
          padding: widget.padding,
          child: SizedBox(
            width: double.infinity,
            child: KeyedSubtree(key: _key, child: widget.child),
          ),
        );
        if (_scroll) return SingleChildScrollView(child: content);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measure(box.maxHeight),
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: box.maxWidth, child: content),
        );
      },
    );
  }
}
