import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// A small one-shot confetti burst (no package). Ignores touches, and
/// shows nothing when the phone asks to reduce motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.seed = 7});

  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(math.Random r)
    : x = r.nextDouble(),
      vx = (r.nextDouble() - 0.5) * 0.6,
      vy = 0.6 + r.nextDouble() * 0.8,
      size = 5 + r.nextDouble() * 6,
      spin = (r.nextDouble() - 0.5) * 12,
      color = moduleAccents[r.nextInt(moduleAccents.length)];

  final double x, vx, vy, size, spin;
  final Color color;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final List<_Piece> _pieces = List.generate(70, (_) => _Piece(_random));
  late final math.Random _random = math.Random(widget.seed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final paint = Paint();
    final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    for (final p in pieces) {
      final x = (p.x + p.vx * t) * size.width;
      final y = (-0.1 + p.vy * t + 0.5 * t * t) * size.height;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
