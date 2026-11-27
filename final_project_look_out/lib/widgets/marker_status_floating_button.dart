import 'package:flutter/material.dart';

class MarkerStatusFloatingButton extends StatelessWidget {
  const MarkerStatusFloatingButton({
    super.key,
    required this.isFull,
    required this.onPressed,
    this.heroTag,
  });

  final bool isFull;
  final VoidCallback onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isFull ? Colors.red : Colors.green;

    return FloatingActionButton.extended(
      heroTag: heroTag,
      tooltip: 'Change PUV status',
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 3,
      icon: const Icon(Icons.directions_bus),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Marker'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isFull ? 'Full' : 'Vacant',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
