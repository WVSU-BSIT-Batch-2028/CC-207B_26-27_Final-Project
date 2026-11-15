import 'package:flutter/material.dart';

// Slide-over right drawer for viewing and editing item details on tablets
class TabletDetailsDrawer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback onClose;
  final double width;

  const TabletDetailsDrawer({
    super.key,
    required this.title,
    this.subtitle,
    this.statusBadge,
    required this.child,
    this.actions,
    required this.onClose,
    this.width = 440,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (statusBadge != null) ...[
                        const SizedBox(height: 6),
                        statusBadge!,
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: onClose,
                  tooltip: 'Close drawer',
                ),
              ],
            ),
          ),

          // Primary Actions at the top if provided (as shown in reservations drawer)
          if (actions != null && actions!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: actions!
                    .map((action) => Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: action,
                        )))
                    .toList(),
              ),
            ),

          // Drawer Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
