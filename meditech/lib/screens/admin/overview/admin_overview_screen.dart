import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/admin_overview.dart';
import '../../../providers/admin_overview_providers.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../providers/catalogue_providers.dart';
import '../../../providers/medicine_request_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../catalogue/catalogue_screen.dart';
import '../pharmacies/pharmacies_screen.dart';
import '../requests/medicine_requests_screen.dart';

// The admin's first screen (wireframe A-02)
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key, this.onOpen, this.onSignOut, this.showHeader = true});

  // Routing can take these over; until then the screen handles them itself
  final void Function(String kind, String id)? onOpen;
  final VoidCallback? onSignOut;

  // Turn off when Emman's admin frame already shows a header
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);

    // Open the right screen for a card, shortcut, or to-do item, filtered to
    // what was tapped (and with that item's drawer open, for to-do items)
    void open(String kind, [String? id]) {
      if (onOpen != null && id != null) return onOpen!(kind, id);

      final Widget screen;
      switch (kind) {
        case 'application' || 'active_pharmacies' || 'lto_expiring':
          ref.read(selectedPharmacyProvider.notifier).select(id);
          screen = PharmaciesScreen(
            initialChip: switch (kind) {
              'application' => 'pending_approval',
              'active_pharmacies' => 'active',
              _ => 'lto_expiring',
            },
          );
        case 'medicine':
          ref.read(catalogueFilterProvider.notifier).showOnly('draft');
          ref.read(selectedMedicineProvider.notifier).select(id);
          screen = const CatalogueScreen();
        default:
          ref.read(requestStatusProvider.notifier).set('open');
          screen = const MedicineRequestsScreen();
      }
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen))
          .then((_) => ref.invalidate(adminOverviewProvider)); // fresh numbers when coming back
    }

    return Scaffold(
      body: AsyncView<AdminOverview?>(
        value: overview,
        onRetry: () => ref.invalidate(adminOverviewProvider),
        isEmpty: (o) => o == null,
        emptyMessage: 'Only administrators can see the overview.',
        builder: (o) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminOverviewProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (showHeader) ...[
                _Header(onSignOut: onSignOut, onRefresh: () => ref.invalidate(adminOverviewProvider)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SummaryCards(overview: o!, onOpen: open),
              const SizedBox(height: AppSpacing.lg),
              _AttentionCard(items: o.todo, onOpen: open),
              const SizedBox(height: AppSpacing.lg),

              // Glance and shortcuts: side by side on wide screens
              LayoutBuilder(
                builder: (context, box) {
                  final glance = _PlatformGlance(overview: o);
                  final shortcuts = _QuickActions(overview: o, onOpen: open);
                  if (box.maxWidth < 900) {
                    return Column(
                      children: [
                        glance,
                        const SizedBox(height: AppSpacing.lg),
                        shortcuts,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: glance),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(flex: 2, child: shortcuts),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Title, subtitle, refresh, and the admin menu
class _Header extends StatelessWidget {
  const _Header({this.onSignOut, required this.onRefresh});

  final VoidCallback? onSignOut;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: AppSpacing.xs),
              Text('Monitor MediTech platform activity and operations.', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (_) => onSignOut?.call(),
          itemBuilder: (_) => const [PopupMenuItem(value: 'sign_out', child: Text('Sign out'))],
          child: const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Admin', style: TextStyle(fontWeight: FontWeight.w600)),
              Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ],
    );
  }
}

// The five summary cards
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.overview, required this.onOpen});

  final AdminOverview overview;
  final void Function(String kind, [String? id]) onOpen;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final cards = [
      _StatCard(
        Icons.storefront,
        AppColors.primary,
        o.pendingApplications,
        'Pending applications',
        () => onOpen('application'),
      ),
      _StatCard(
        Icons.local_pharmacy,
        AppColors.primary,
        o.activePharmacies,
        'Active pharmacies',
        () => onOpen('active_pharmacies'),
      ),
      _StatCard(
        Icons.medication_outlined,
        AppColors.info,
        o.medicinesPendingReview,
        'Medicines pending review',
        () => onOpen('medicine'),
      ),
      _StatCard(Icons.assignment_outlined, AppColors.warning, o.openRequests, 'Open requests', () => onOpen('request')),
      _StatCard(
        Icons.event_busy_outlined,
        AppColors.danger,
        o.ltoExpiringSoon,
        'LTOs expiring in 60 days',
        () => onOpen('lto_expiring'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth >= 1000
            ? 5
            : box.maxWidth >= 640
            ? 3
            : 2;
        final width = (box.maxWidth - AppSpacing.md * (perRow - 1)) / perRow;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}

// One summary card: big icon, number, label, and arrow
class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.color, this.count, this.label, this.onTap);

  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('$count', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// "Needs your attention" with rich rows
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.items, required this.onOpen});

  final List<TodoItem> items;
  final void Function(String kind, [String? id]) onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.priority_high, color: Colors.white, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text('Needs your attention', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${items.length} pending',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            if (items.isEmpty)
              const StateMessage(icon: Icons.check_circle_outline, message: 'All caught up!')
            else
              for (final item in items) ...[
                _AttentionRow(item: item, onOpen: onOpen),
                if (item != items.last) const Divider(height: AppSpacing.xl),
              ],
          ],
        ),
      ),
    );
  }
}

// One to-do row: icon, title, date, detail, status chip, and action button
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onOpen});

  final TodoItem item;
  final void Function(String kind, [String? id]) onOpen;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy');
    final (icon, color, chip, button) = switch (item.kind) {
      'application' => (Icons.storefront, AppColors.primary, 'Awaiting administrator review', 'Review application'),
      'request' => (Icons.assignment_outlined, AppColors.warning, 'Open request', 'Review request'),
      'medicine' => (Icons.medication_outlined, AppColors.info, 'Pending FDA check', 'Review medicine'),
      _ => (Icons.event_busy_outlined, AppColors.danger, 'LTO expiring soon', 'View pharmacy'),
    };
    final dateLabel = item.kind == 'lto_expiring' ? 'Expires' : 'Submitted on';

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 640;

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                if (item.since != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$dateLabel ${date.format(item.since!)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(item.detail, style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                chip,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        );

        final action = FilledButton(
          onPressed: () => onOpen(item.kind, item.id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(button), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)],
          ),
        );

        final avatar = CircleAvatar(
          radius: 32,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 30),
        );

        // Narrow screens: button below; wide: button on the right
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: info),
            const SizedBox(width: AppSpacing.md),
            action,
          ],
        );
      },
    );
  }
}

// "Platform at a glance": bars built from the counts already loaded
class _PlatformGlance extends StatelessWidget {
  const _PlatformGlance({required this.overview});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final pharmacies = o.activePharmacies + o.pendingApplications + o.inactivePharmacies;
    final medicines = o.activeMedicines + o.medicinesPendingReview;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm),
                Text('Platform at a glance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Pharmacies ($pharmacies)', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            _Bar('Active', o.activePharmacies, pharmacies, AppColors.primary),
            _Bar('Pending', o.pendingApplications, pharmacies, AppColors.warning),
            _Bar('Inactive', o.inactivePharmacies, pharmacies, AppColors.danger),
            const SizedBox(height: AppSpacing.lg),
            Text('Medicines ($medicines)', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            _Bar('Active', o.activeMedicines, medicines, AppColors.primary),
            _Bar('Pending review', o.medicinesPendingReview, medicines, AppColors.info),
          ],
        ),
      ),
    );
  }
}

// One labelled bar: how many out of the total
class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.total, this.color);

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : value / total,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// "Quick actions": a timeline of shortcuts with their counts
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.overview, required this.onOpen});

  final AdminOverview overview;
  final void Function(String kind, [String? id]) onOpen;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final actions = [
      (Icons.storefront, 'Review applications', '${o.pendingApplications} waiting', 'application'),
      (Icons.medication_outlined, 'Check medicines', '${o.medicinesPendingReview} pending review', 'medicine'),
      (Icons.assignment_outlined, 'Handle requests', '${o.openRequests} open', 'request'),
      (Icons.event_busy_outlined, 'Watch expiring licenses', '${o.ltoExpiringSoon} within 60 days', 'lto_expiring'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm),
                Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < actions.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline dot and line
                    Column(
                      children: [
                        const SizedBox(height: 18),
                        const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                        if (i < actions.length - 1) Expanded(child: Container(width: 2, color: AppColors.primaryLight)),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => onOpen(actions[i].$4),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(actions[i].$1, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(actions[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(actions[i].$3, style: const TextStyle(color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
