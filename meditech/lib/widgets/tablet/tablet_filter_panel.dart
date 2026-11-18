import 'package:flutter/material.dart';

// Popover/anchored filter panel used beside the Filters button in tablet tables
class TabletFilterPanel extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final int activeFilterCount;
  final VoidCallback? onClose;
  final double width;

  const TabletFilterPanel({
    super.key,
    required this.title,
    required this.content,
    required this.onReset,
    required this.onApply,
    this.activeFilterCount = 0,
    this.onClose,
    this.width = 340,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Header with Reset link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF4B5563),
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Body content (filter checkboxes, pills, radios)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: content,
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Action button
          Padding(
            padding: const EdgeInsets.all(14),
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6B3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                activeFilterCount > 0
                    ? 'Show results ($activeFilterCount)'
                    : 'Show results',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
