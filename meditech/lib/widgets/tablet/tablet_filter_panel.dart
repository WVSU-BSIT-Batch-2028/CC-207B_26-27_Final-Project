import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    this.width = 320,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x181A2E22),
            blurRadius: 20,
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF2E6B46),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E6B46),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body content (filter checkboxes, pills, radios)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: content,
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6B46),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Show results',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
