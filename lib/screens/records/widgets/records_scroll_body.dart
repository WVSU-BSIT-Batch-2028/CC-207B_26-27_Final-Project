import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// The scrolling area under the header: centered with a maximum width (so a
/// wide browser window does not stretch the cards), pull-to-refresh, and the
/// standard page padding. Shared by Records Overview and Consultations.
class RecordsScrollBody extends StatelessWidget {
  const RecordsScrollBody({super.key, required this.onRefresh, required this.children});

  /// Called when the user pulls down. Should return when loading is finished.
  final Future<void> Function() onRefresh;

  /// The list content (cards, pills, or a loading / empty / error view).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: onRefresh,
          child: ListView(
            // Always scrollable, so pull-to-refresh works even with a short list.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}
