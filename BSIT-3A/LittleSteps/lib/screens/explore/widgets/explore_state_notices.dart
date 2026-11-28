import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';

/// Sidebar card inviting caregivers to open the AI Idea Helper.
class IdeaHelperEntryCard extends StatelessWidget {
  /// Creates an [IdeaHelperEntryCard].
  const IdeaHelperEntryCard({super.key, required this.onTap});

  /// Callback invoked when the caregiver taps "Get a play idea".
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need a play idea?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Tell us how much time you have and what is nearby.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.space12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Get a play idea'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Skeleton placeholder card shown while catalog activities are loading.
class ActivityLoadingSkeleton extends StatelessWidget {
  /// Creates an [ActivityLoadingSkeleton].
  const ActivityLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 72, width: double.infinity, color: placeholder),
            const SizedBox(height: AppSpacing.space12),
            Container(height: 20, width: 180, color: placeholder),
            const SizedBox(height: AppSpacing.space8),
            Container(height: 14, width: double.infinity, color: placeholder),
            const SizedBox(height: AppSpacing.space8),
            Container(height: 14, width: 220, color: placeholder),
          ],
        ),
      ),
    );
  }
}

/// Status banner shown when the Explore catalog cannot be loaded offline.
class OfflineCatalogNotice extends StatelessWidget {
  /// Creates an [OfflineCatalogNotice].
  const OfflineCatalogNotice({super.key});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).extension<AppStatusColors>()!.offlineBackground,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context)
                  .extension<AppStatusColors>()!
                  .offlineForeground,
            ),
            const SizedBox(width: AppSpacing.space8),
            const Expanded(
              child: Text('You are offline. Reconnect to load activities.'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Error notice card with a retry button for failed catalog requests.
class CatalogErrorNotice extends StatelessWidget {
  /// Creates a [CatalogErrorNotice].
  const CatalogErrorNotice({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Human-readable description of the load failure.
  final String message;

  /// Callback invoked when the caregiver taps "Try again".
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).extension<AppStatusColors>()!.errorBackground,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.space8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
