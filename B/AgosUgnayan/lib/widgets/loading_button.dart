// A full-width main button that shows a small spinner and can't be tapped
// while its action is running, so nothing gets submitted twice.

import 'package:flutter/material.dart';

/// FilledButton with a loading state.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Full width, like the website's main buttons (.btn-block).
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        // null disables the button.
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
