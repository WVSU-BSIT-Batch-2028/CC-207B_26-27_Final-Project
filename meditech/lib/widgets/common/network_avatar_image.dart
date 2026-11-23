import 'dart:convert';

import 'package:flutter/material.dart';

/// Avatar image for a network URL or an inline data URL.
class NetworkAvatarImage extends StatelessWidget {
  const NetworkAvatarImage({
    super.key,
    required this.url,
    required this.radius,
    this.fallback,
    this.backgroundColor,
  });

  final String url;
  final double radius;
  final Widget? fallback;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma < 0) return _box(size, fallback);
      try {
        final bytes = base64Decode(url.substring(comma + 1));
        return ClipOval(
          child: Image.memory(
            bytes,
            key: ValueKey(url.length),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => _box(size, fallback),
          ),
        );
      } catch (_) {
        return _box(size, fallback);
      }
    }

    return ClipOval(
      child: Image.network(
        url,
        key: ValueKey(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: false,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _box(size, fallback),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _box(
            size,
            Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: backgroundColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _box(double size, Widget? child) {
    return SizedBox(
      width: size,
      height: size,
      child: child ?? ColoredBox(color: backgroundColor ?? Colors.grey),
    );
  }
}
