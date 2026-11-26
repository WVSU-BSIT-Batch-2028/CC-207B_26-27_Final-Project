import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// The scrolling area under the header: content centered with a maximum width
/// (so a wide browser window does not stretch the cards), pull-to-refresh,
/// the standard page padding, and a scroll bar that is always visible at the
/// right edge of the window. Shared by the Records and doctor Patients screens.
class RecordsScrollBody extends StatefulWidget {
  const RecordsScrollBody({super.key, required this.onRefresh, required this.children});

  /// Called when the user pulls down. Should return when loading is finished.
  final Future<void> Function() onRefresh;

  /// The list content (cards, pills, or a loading / empty / error view).
  final List<Widget> children;

  @override
  State<RecordsScrollBody> createState() => _RecordsScrollBodyState();
}

class _RecordsScrollBodyState extends State<RecordsScrollBody> {
  /// Content never gets wider than this.
  static const double _maxWidth = 640;

  /// The scroll bar needs its own controller to stay visible on the web.
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Extra side padding centers the 640-wide content, while the list
        // itself fills the window, so its scroll bar sits at the window edge.
        final extra = constraints.maxWidth > _maxWidth
            ? (constraints.maxWidth - _maxWidth) / 2
            : 0.0;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: widget.onRefresh,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: ListView(
              controller: _controller,
              // Always scrollable, so pull-to-refresh works even with a short list.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md + extra,
                AppSpacing.md,
                AppSpacing.md + extra,
                AppSpacing.xl,
              ),
              children: widget.children,
            ),
          ),
        );
      },
    );
  }
}
