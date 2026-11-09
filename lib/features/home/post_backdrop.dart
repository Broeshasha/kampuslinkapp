import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-screen backdrop of a Home post: the module colour fading into the
/// app surface (top to bottom), with faint rock-strata contour lines in the
/// corner. It runs behind the status bar and the floating navigation bar.
class PostBackdrop extends StatelessWidget {
  const PostBackdrop({
    super.key,
    required this.accent,
    this.strength = 0.38,
    this.colors,
  });

  final Color accent;

  /// How much of the module colour shows at the top (0 to 1).
  final double strength;

  /// An equipped Shop skin replaces the module gradient.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final base = context.kc.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final k = dark ? strength : strength * 0.7;
    final custom = colors;
    final gradient = LinearGradient(
      begin: const Alignment(-0.3, -1),
      end: const Alignment(0.3, 1),
      colors:
          custom ??
          [
            Color.lerp(base, accent, k)!,
            Color.lerp(base, accent, k * 0.35)!,
            base,
          ],
      stops: custom == null ? const [0.0, 0.45, 1.0] : null,
    );
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _StrataPainter(
              dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : accent.withValues(alpha: 0.14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Topographic contour lines, centred near the bottom end corner. Painted
/// once (the layer is cached), so scrolling never pays for it.
class _StrataPainter extends CustomPainter {
  const _StrataPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final k = size.width / 390;
    final cx = size.width * 0.85;
    final cy = size.height * 0.83;
    for (var i = 1; i <= 14; i++) {
      final r = 34.0 * i * k;
      final path = Path();
      for (var a = 0; a <= 360; a += 6) {
        final t = a * math.pi / 180;
        final rr =
            r *
            (1 + 0.07 * math.sin(3 * t + i * 0.6) + 0.04 * math.sin(5 * t + i));
        final x = cx + rr * math.cos(t) * 1.1;
        final y = cy + rr * math.sin(t) * 0.95;
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrataPainter old) => old.color != color;
}
