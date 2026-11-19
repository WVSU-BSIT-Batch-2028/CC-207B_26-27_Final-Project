import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/customer_profile.dart';
import '../../../providers/profile_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shows the signed-in customer's saved details
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.embedded = false});

  // True when shown inside the customer bottom tabs (no second app bar)
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider);
    final body = AsyncView<CustomerProfile?>(
      value: profile,
      isEmpty: (data) => data == null,
      emptyMessage: 'Sign in to see your profile.',
      onRetry: () => ref.invalidate(customerProfileProvider),
      builder: (data) {
        final saved = data!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileRow(label: 'Name', value: saved.fullName),
            _ProfileRow(label: 'Mobile', value: saved.mobile),
            _ProfileRow(label: 'Email', value: saved.email),
            _ProfileRow(label: 'Birthdate', value: saved.birthdate),
            _ProfileRow(label: 'Privacy notice', value: saved.consentVersion),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: const Text('Read the privacy notice'),
            ),
          ],
        );
      },
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: body,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(value),
        ],
      ),
    );
  }
}
