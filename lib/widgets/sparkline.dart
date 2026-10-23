import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Minimal smooth trend line with a soft gradient fill (no chart package).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.height = 34});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    Offset point(int i) => Offset(
          i * dx,
          size.height - ((values[i] - minV) / range) * (size.height - 8) - 4,
        );

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = point(i - 1);
      final cur = point(i);
      final cx = (prev.dx + cur.dx) / 2;
      line.cubicTo(cx, prev.dy, cx, cur.dy, cur.dx, cur.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(point(values.length - 1), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
