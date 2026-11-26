import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/paper_theme.dart';

enum PaperKind { graph, ruled, plain }

/// A page section drawn on its own sheet of paper (grain, creases, lines).
class PaperSection extends StatelessWidget {
  const PaperSection({
    required this.kind,
    required this.seed,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 96, 20, 72),
    super.key,
  });

  final PaperKind kind;
  final int seed;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - padding.horizontal;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _PaperPainter(kind, seed),
        child: Padding(
          padding: padding,
          child: Center(
            child: SizedBox(width: math.min(available, 1120), child: child),
          ),
        ),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.kind, this.seed);

  final PaperKind kind;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Paper.paper);
    final rnd = math.Random(seed);

    // Soft light and shadow blotches, like uneven crumpled paper.
    for (var i = 0; i < size.height / 90; i++) {
      final c = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final r = 80 + rnd.nextDouble() * 180;
      final dark = rnd.nextBool();
      final tint = (dark ? Paper.ink : Colors.white).withValues(
        alpha: dark ? 0.035 : 0.5,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [tint, Colors.transparent])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Faint fold creases.
    final crease = Paint()
      ..color = Paper.ink.withValues(alpha: 0.045)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < size.height / 160; i++) {
      var p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final path = Path()..moveTo(p.dx, p.dy);
      for (var j = 0; j < 4; j++) {
        p += Offset(
          (rnd.nextDouble() - 0.3) * 120,
          (rnd.nextDouble() - 0.5) * 90,
        );
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, crease);
    }

    if (kind == PaperKind.graph) {
      final line = Paint()
        ..color = Paper.gridLine.withValues(alpha: 0.28)
        ..strokeWidth = 0.8;
      for (double x = 0; x <= size.width; x += 28) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
      for (double y = 0; y <= size.height; y += 28) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    } else if (kind == PaperKind.ruled) {
      final line = Paint()
        ..color = Paper.gridLine.withValues(alpha: 0.35)
        ..strokeWidth = 0.9;
      for (double y = 30; y <= size.height; y += 32) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      if (size.width > 700) {
        canvas.drawLine(
          const Offset(72, 0),
          Offset(72, size.height),
          Paint()
            ..color = Paper.tomato.withValues(alpha: 0.3)
            ..strokeWidth = 1.4,
        );
      }
    }

    // Paper grain.
    final count = (size.width * size.height / 900).toInt().clamp(0, 2500);
    final grain = [
      for (var i = 0; i < count; i++)
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    ];
    canvas.drawPoints(
      PointMode.points,
      grain,
      Paint()
        ..color = Paper.ink.withValues(alpha: 0.06)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.kind != kind || old.seed != seed;
}

/// Torn-edge clip used by labels and tape.
class _ZigZagClipper extends CustomClipper<Path> {
  const _ZigZagClipper([this.tooth = 5.0]);

  final double tooth;

  @override
  Path getClip(Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0);
    var y = 0.0;
    var out = false;
    while (y < s.height) {
      y = math.min(y + tooth, s.height);
      p.lineTo(out ? s.width : s.width - tooth, y);
      out = !out;
    }
    p.lineTo(0, s.height);
    y = s.height;
    out = false;
    while (y > 0) {
      y = math.max(y - tooth, 0);
      p.lineTo(out ? 0 : tooth, y);
      out = !out;
    }
    return p..close();
  }

  @override
  bool shouldReclip(_ZigZagClipper old) => old.tooth != tooth;
}

class Tape extends StatelessWidget {
  const Tape({
    this.angle = -0.08,
    this.color = Paper.tape,
    this.width = 76,
    super.key,
  });

  final double angle;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: const _ZigZagClipper(4),
        child: Container(
          width: width,
          height: 24,
          color: color.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

/// Small torn-paper tag in a bright color.
class TornLabel extends StatelessWidget {
  const TornLabel(
    this.text, {
    this.color = Paper.mustard,
    this.textColor = Paper.ink,
    this.angle = 0,
    super.key,
  });

  final String text;
  final Color color;
  final Color textColor;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: const _ZigZagClipper(),
        child: Container(
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(text, style: Paper.mono(12, color: textColor)),
        ),
      ),
    );
  }
}

class StickyNote extends StatelessWidget {
  const StickyNote({
    required this.color,
    required this.child,
    this.angle = 0,
    this.width,
    super.key,
  });

  final Color color;
  final Widget child;
  final double angle;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: width,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(3, 6),
                ),
              ],
            ),
            child: child,
          ),
          const Positioned(top: 0, child: Tape(angle: -0.05, width: 64)),
        ],
      ),
    );
  }
}

enum ScribbleKind { underline, circle }

/// Hand-drawn underline or circle around a child (usually a word).
class Scribble extends StatelessWidget {
  const Scribble({
    required this.child,
    this.kind = ScribbleKind.circle,
    this.color = Paper.tomato,
    super.key,
  });

  final Widget child;
  final ScribbleKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _ScribblePainter(kind, color),
      child: Padding(
        padding: kind == ScribbleKind.circle
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
            : const EdgeInsets.only(bottom: 8),
        child: child,
      ),
    );
  }
}

class _ScribblePainter extends CustomPainter {
  _ScribblePainter(this.kind, this.color);

  final ScribbleKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    if (kind == ScribbleKind.circle) {
      path
        ..moveTo(w * 0.08, h * 0.35)
        ..cubicTo(w * 0.2, -h * 0.05, w * 0.85, -h * 0.05, w * 0.97, h * 0.4)
        ..cubicTo(w * 1.02, h * 0.85, w * 0.5, h * 1.08, w * 0.15, h * 0.92)
        ..cubicTo(-w * 0.03, h * 0.75, 0, h * 0.3, w * 0.2, h * 0.12);
    } else {
      path
        ..moveTo(0, h - 4)
        ..quadraticBezierTo(w * 0.25, h - 10, w * 0.5, h - 4)
        ..quadraticBezierTo(w * 0.75, h + 2, w, h - 7);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScribblePainter old) =>
      old.kind != kind || old.color != color;
}

class DoodleArrow extends StatelessWidget {
  const DoodleArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 64,
      height: 44,
      child: CustomPaint(painter: _ArrowPainter()),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = Paper.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final tip = Offset(size.width - 6, size.height * 0.28);

    canvas.drawPath(
      Path()
        ..moveTo(2, size.height - 4)
        ..quadraticBezierTo(size.width * 0.2, 0, tip.dx, tip.dy),
      pen,
    );
    canvas.drawLine(tip, tip + const Offset(-14, -9), pen);
    canvas.drawLine(tip, tip + const Offset(-12, 10), pen);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

/// Lifts and straightens a child on hover; also handles taps.
class HoverLift extends StatefulWidget {
  const HoverLift({required this.child, this.angle = 0, this.onTap, super.key});

  final Widget child;
  final double angle;
  final VoidCallback? onTap;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transformAlignment: Alignment.center,
            transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0)
              ..rotateZ(_hovered ? 0 : widget.angle),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Stamp-style button with a hard offset shadow.
class PaperButton extends StatelessWidget {
  const PaperButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.fill = Paper.cobalt,
    this.textColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color fill;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: Paper.ink, width: 1.6),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Paper.ink, offset: Offset(4, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(label.toUpperCase(), style: Paper.mono(13, color: textColor)),
          ],
        ),
      ),
    );
  }
}
