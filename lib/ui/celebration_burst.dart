import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// The Shop celebration played on a right answer: 'confetti', 'stars' or
/// 'fireworks'. One shot, ignores touches, nothing when reduce motion is on.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({super.key, required this.style, this.onDone});

  final String style;
  final VoidCallback? onDone;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _Bit {
  _Bit(math.Random r)
    : x = r.nextDouble(),
      angle = r.nextDouble() * math.pi * 2,
      speed = 0.25 + r.nextDouble() * 0.45,
      size = 5 + r.nextDouble() * 7,
      spin = (r.nextDouble() - 0.5) * 10,
      color = moduleAccents[r.nextInt(moduleAccents.length)];

  final double x, angle, speed, size, spin;
  final Color color;
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _random = math.Random();
  late final List<_Bit> _bits = List.generate(60, (_) => _Bit(_random));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
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
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(_bits, _c.value, widget.style),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.bits, this.t, this.style);

  final List<_Bit> bits;
  final double t;
  final String style;

  Path _star(double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(math.cos(a) * rad, math.sin(a) * rad);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint();
    for (final b in bits) {
      paint.color = b.color.withValues(alpha: fade);
      Offset pos;
      if (style == 'fireworks') {
        final center = Offset(size.width / 2, size.height * 0.4);
        final d = b.speed * size.shortestSide * Curves.easeOut.transform(t);
        pos =
            center +
            Offset(math.cos(b.angle) * d, math.sin(b.angle) * d + 60 * t * t);
        canvas.drawCircle(pos, b.size / 3, paint);
        continue;
      }
      pos = Offset(
        b.x * size.width + math.sin(b.angle + t * 6) * 18,
        -20 + t * size.height * (0.6 + b.speed),
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.spin * t);
      if (style == 'stars') {
        canvas.drawPath(_star(b.size), paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
