import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A shimmering placeholder box matching the shape of content that's still
/// loading. Feels responsive even during a real 3-4s network wait, unlike
/// a bare spinner which reads as "frozen" after about a second.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surface, AppColors.border, t),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// A skeleton shaped like a single feed post card (avatar + two text lines).
/// Drop 2-3 of these in a list while the real feed loads.
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 32, height: 32, borderRadius: BorderRadius.all(Radius.circular(16))),
              const SizedBox(width: 10),
              SkeletonBox(width: 100, height: 12, borderRadius: BorderRadius.circular(4)),
            ],
          ),
          const SizedBox(height: 10),
          SkeletonBox(height: 12, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 6),
          SkeletonBox(width: 200, height: 12, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}
