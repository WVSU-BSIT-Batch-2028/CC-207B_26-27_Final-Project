import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/report_image_storage.dart';
import '../theme/paper_theme.dart';
import 'paper_widgets.dart';

/// A report's photo, shown as a crumpled paper ball that unfolds when tapped.
class ReportImage extends StatefulWidget {
  const ReportImage({required this.type, required this.reportId, super.key});

  /// 'lost' or 'found'.
  final String type;
  final String reportId;

  @override
  State<ReportImage> createState() => _ReportImageState();
}

class _ReportImageState extends State<ReportImage> {
  Future<ReportImageData?>? _future;
  bool _open = false;

  void _unfold() {
    setState(() {
      _open = true;
      // The photo is only downloaded the first time it is unfolded.
      _future ??= ReportImageStorage.load(widget.type, widget.reportId);
    });
  }

  void _fold() {
    setState(() {
      _open = false;
    });
  }

  void _retry() {
    setState(() {
      _future = ReportImageStorage.load(widget.type, widget.reportId);
    });
  }

  void _enlarge(ReportImageData image) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(image.bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The crumpled paper, shown before anyone taps.
  Widget _crumpled() {
    return HoverLift(
      key: const ValueKey('crumpled'),
      angle: -0.02,
      onTap: _unfold,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Paper.ink, width: 1.4),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Paper.ink, offset: Offset(3, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CustomPaint(painter: _CrumpledPaperPainter()),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PHOTO ATTACHED', style: Paper.mono(11)),
                Text(
                  'tap to unfold',
                  style: Paper.hand(24, color: Paper.tomato),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // What shows inside the photo frame: spinner, error, or the photo.
  Widget _photoContent() {
    return FutureBuilder<ReportImageData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final image = snapshot.data;

        if (snapshot.hasError || image == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, size: 32),
                const SizedBox(height: 6),
                Text(
                  snapshot.hasError
                      ? 'Could not load the photo'
                      : 'Photo unavailable',
                  style: Paper.body(14, color: Paper.ink),
                ),
                if (snapshot.hasError)
                  TextButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          );
        }

        return Semantics(
          label: 'Photo of the reported item. Tap to enlarge.',
          button: true,
          child: InkWell(
            onTap: () => _enlarge(image),
            child: Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }

  // The unfolded photo, taped on like a snapshot.
  Widget _unfolded() {
    return Column(
      key: const ValueKey('unfolded'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Transform.rotate(
              angle: 0.012,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Paper.ink, width: 1.4),
                      boxShadow: const [
                        BoxShadow(color: Paper.ink, offset: Offset(4, 4)),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _photoContent(),
                    ),
                  ),
                  const Positioned(
                    top: -12,
                    left: 0,
                    right: 0,
                    child: Center(child: Tape(angle: -0.04, width: 84)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('tap the photo to enlarge', style: Paper.hand(20)),
            TextButton.icon(
              onPressed: _fold,
              icon: const Icon(Icons.unfold_less_rounded, size: 18),
              label: Text('FOLD BACK', style: Paper.mono(11)),
              style: TextButton.styleFrom(foregroundColor: Paper.ink),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
          child: _open ? _unfolded() : _crumpled(),
        ),
      ),
    );
  }
}

/// Draws a small crumpled ball of paper with creases and a hard shadow.
class _CrumpledPaperPainter extends CustomPainter {
  const _CrumpledPaperPainter();

  // How far each corner of the ball sits from the center (makes it lumpy).
  static const _radii = [
    0.92,
    0.7,
    0.98,
    0.74,
    0.95,
    0.68,
    0.97,
    0.76,
    0.9,
    0.72,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final count = _radii.length;

    final points = <Offset>[
      for (var i = 0; i < count; i++)
        center +
            Offset(
                  math.cos(2 * math.pi * i / count - 0.4),
                  math.sin(2 * math.pi * i / count - 0.4),
                ) *
                (radius * _radii[i]),
    ];

    final outline = Path()..addPolygon(points, true);

    // Hard offset shadow, like the rest of the site.
    canvas.drawPath(
      outline.shift(const Offset(3, 3)),
      Paint()..color = Paper.ink,
    );

    // Paper facets in alternating tints.
    for (var i = 0; i < count; i++) {
      final next = points[(i + 1) % count];
      final facet = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(points[i].dx, points[i].dy)
        ..lineTo(next.dx, next.dy)
        ..close();
      final tint = i.isEven ? Colors.white : Paper.tape;
      canvas.drawPath(facet, Paint()..color = tint);
    }

    // Crease lines.
    final crease = Paint()
      ..color = Paper.ink.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      canvas.drawLine(center, points[i], crease);
      if (i.isEven) {
        canvas.drawLine(points[i], points[(i + 3) % count], crease);
      }
    }

    // Outline.
    canvas.drawPath(
      outline,
      Paint()
        ..color = Paper.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CrumpledPaperPainter oldDelegate) => false;
}
