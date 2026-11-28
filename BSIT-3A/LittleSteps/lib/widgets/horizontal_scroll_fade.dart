import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Applies soft edge fades when a horizontal scroll view can scroll further.
///
/// Keeps a single [ShaderMask] unconditionally mounted around [child] so
/// toggling edge fades never unmounts the scrollable or resets its scroll
/// offset.
class HorizontalScrollFade extends StatefulWidget {
  /// Creates a [HorizontalScrollFade].
  const HorizontalScrollFade({super.key, required this.child});

  /// Horizontally scrollable child widget.
  final Widget child;

  @override
  State<HorizontalScrollFade> createState() => _HorizontalScrollFadeState();
}

class _HorizontalScrollFadeState extends State<HorizontalScrollFade> {
  static const double _edgeThreshold = 4;

  bool _showLeftFade = false;
  bool _showRightFade = false;

  void _updateEdges(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;
    final hasOverflow = metrics.maxScrollExtent > _edgeThreshold;
    final nextLeft = hasOverflow && metrics.extentBefore > _edgeThreshold;
    final nextRight = hasOverflow && metrics.extentAfter > _edgeThreshold;
    if (nextLeft != _showLeftFade || nextRight != _showRightFade) {
      setState(() {
        _showLeftFade = nextLeft;
        _showRightFade = nextRight;
      });
    }
  }

  Shader _buildMaskShader(Rect bounds) {
    const opaque = AppColors.surfaceCard;
    if (!_showLeftFade && !_showRightFade) {
      return const LinearGradient(colors: [opaque, opaque])
          .createShader(bounds);
    }
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _showLeftFade ? Colors.transparent : opaque,
        opaque,
        opaque,
        _showRightFade ? Colors.transparent : opaque,
      ],
      stops: const [0.0, 0.06, 0.9, 1.0],
    ).createShader(bounds);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _updateEdges(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _updateEdges(notification.metrics);
          return false;
        },
        child: ShaderMask(
          shaderCallback: _buildMaskShader,
          blendMode: BlendMode.dstIn,
          child: widget.child,
        ),
      ),
    );
  }
}
