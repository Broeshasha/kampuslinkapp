import 'package:flutter/material.dart';

class KampusMark extends StatelessWidget {
  final double size;
  final Color color;

  const KampusMark({super.key, this.size = 40, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _KampusMarkPainter(color: color),
    );
  }
}

class _KampusMarkPainter extends CustomPainter {
  final Color color;
  _KampusMarkPainter({required this.color});

  Path _buildPath() {
    final p = Path();
    p.moveTo(-58, 80);
    p.lineTo(-71, -58);
    p.cubicTo(-73, -72, -68, -84, -56, -90);
    p.cubicTo(-47, -94, -38, -90, -34, -80);
    p.cubicTo(-38, -78, -42, -73, -41, -65);
    p.lineTo(-18, 10);
    p.lineTo(0, -40);
    p.lineTo(18, 10);
    p.lineTo(41, -65);
    p.cubicTo(42, -73, 38, -78, 34, -80);
    p.cubicTo(38, -90, 47, -94, 56, -90);
    p.cubicTo(68, -84, 73, -72, 71, -58);
    p.lineTo(58, 80);
    p.lineTo(34, 80);
    p.lineTo(42, -40);
    p.lineTo(12, 55);
    p.lineTo(-12, 55);
    p.lineTo(-42, -40);
    p.lineTo(-34, 80);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath();
    final bounds = path.getBounds();
    final longestSide = bounds.width > bounds.height ? bounds.width : bounds.height;
    final scale = (size.shortestSide * 0.74) / longestSide;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KampusMarkPainter oldDelegate) => oldDelegate.color != color;
}
