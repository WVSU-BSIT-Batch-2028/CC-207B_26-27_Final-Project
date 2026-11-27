import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  final double? _size;
  final double _strokeWidth;
  final Color? _color;
  final Alignment _alignment;
  final bool _showText;
  final bool _isLinear;
  final bool _fullScreen;

  // Circular Loader
  const Loader.circular({
    super.key,
    this._size = 40,
    this._strokeWidth = 3,
    this._color,
    this._alignment = Alignment.center,
    this._showText = true,
    this._fullScreen = false,
  }) : _isLinear = false;

  // Linear Loader
  const Loader.linear({
    super.key,
    this._color,
    this._alignment = Alignment.topCenter,
  })  : _size = null,
        _strokeWidth = 3,
        _showText = false,
        _fullScreen = false,
        _isLinear = true;

  @override
  Widget build(BuildContext context) {
    final Widget indicator = _isLinear
        ? LinearProgressIndicator(
            color: _color,
          )
        : SizedBox(
            width: _size,
            height: _size,
            child: CircularProgressIndicator(
              strokeWidth: _strokeWidth,
              color: _color,
            ),
          );

    final Widget loader = Align(
      alignment: _alignment,
      child: _showText
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator,
                const SizedBox(height: 8),
                const Text('Loading...'),
              ],
            )
          : indicator,
    );

    return _fullScreen
        ? SizedBox.expand(child: loader)
        : loader;
  }
}