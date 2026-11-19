
import 'package:flutter/material.dart';

import '../../../services/pharmacy_dashboard_service.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';



// Pharmacy Dashboard screen (Ph-11)
// Shows reservation counts, oldest pending reservations, and inventory health
class PharmacyDashboardScreen extends StatefulWidget {
  PharmacyDashboardScreen({
    super.key,
    PharmacyDashboardService? service,
  }) : service = service ?? PharmacyDashboardService();

  final PharmacyDashboardService service;

  @override
  State<PharmacyDashboardScreen> createState() =>
      _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState
    extends State<PharmacyDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.service.loadDashboard();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = widget.service.loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _DashboardError(
            message: snapshot.error?.toString() ??
                'No dashboard data available.',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final reservationCounts =
            Map<String, int>.from(data['reservation_counts'] as Map);
        final oldestPending =
            List<Map<String, dynamic>>.from(data['oldest_pending'] as List);
        final inventorySnapshot =
            Map<String, int>.from(data['inventory_snapshot'] as Map);

        return _DashboardContent(
          reservationCounts: reservationCounts,
          oldestPending: oldestPending,
          inventorySnapshot: inventorySnapshot,
          onRefresh: _refresh,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Main content — split into left and right columns on wide screens
// ---------------------------------------------------------------------------

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.reservationCounts,
    required this.oldestPending,
    required this.inventorySnapshot,
    required this.onRefresh,
  });

  final Map<String, int> reservationCounts;
  final List<Map<String, dynamic>> oldestPending;
  final Map<String, int> inventorySnapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page header bar
        _PageHeader(onRefresh: onRefresh),
        // Scrollable body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column — reservations
                      Expanded(
                        flex: 3,
                        child: _LeftColumn(
                          reservationCounts: reservationCounts,
                          oldestPending: oldestPending,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      // Right column — inventory health
                      Expanded(
                        flex: 2,
                        child: _InventoryHealthPanel(
                          snapshot: inventorySnapshot,
                        ),
                      ),
                    ],
                  );
                }

                // Narrow — stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LeftColumn(
                      reservationCounts: reservationCounts,
                      oldestPending: oldestPending,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _InventoryHealthPanel(snapshot: inventorySnapshot),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page header
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Overview of reservations and inventory health',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left column — stat cards + pending list
// ---------------------------------------------------------------------------

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.reservationCounts,
    required this.oldestPending,
  });

  final Map<String, int> reservationCounts;
  final List<Map<String, dynamic>> oldestPending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Reservation Overview'),
        const SizedBox(height: AppSpacing.md),
        // 2×2 stat card grid
        _StatCardGrid(
          cards: [
            _StatCardData(
              label: 'Pending',
              value: reservationCounts['pending'] ?? 0,
              icon: Icons.pending_actions_outlined,
              tone: _StatTone.warning,
            ),
            _StatCardData(
              label: 'Confirmed',
              value: reservationCounts['confirmed'] ?? 0,
              icon: Icons.check_circle_outline,
              tone: _StatTone.info,
            ),
            _StatCardData(
              label: 'Ready for Pickup',
              value: reservationCounts['ready_for_pickup'] ?? 0,
              icon: Icons.shopping_bag_outlined,
              tone: _StatTone.success,
            ),
            _StatCardData(
              label: 'Completed',
              value: reservationCounts['completed'] ?? 0,
              icon: Icons.task_alt_outlined,
              tone: _StatTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionLabel(label: 'Oldest Pending Reservations'),
        const SizedBox(height: AppSpacing.md),
        _PendingReservationsCard(reservations: oldestPending),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Right column — inventory health
// ---------------------------------------------------------------------------

class _InventoryHealthPanel extends StatelessWidget {
  const _InventoryHealthPanel({required this.snapshot});

  final Map<String, int> snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Inventory Health'),
        const SizedBox(height: AppSpacing.md),
        _HealthCard(
          items: [
            _HealthRow(
              icon: Icons.medication_outlined,
              label: 'Active listings',
              value: snapshot['active_listings'] ?? 0,
              tone: _StatTone.success,
            ),
            _HealthRow(
              icon: Icons.inventory_2_outlined,
              label: 'Low stock',
              value: snapshot['low_stock'] ?? 0,
              tone: _StatTone.warning,
            ),
            _HealthRow(
              icon: Icons.remove_shopping_cart_outlined,
              label: 'Marked out of stock',
              value: snapshot['marked_out_of_stock'] ?? 0,
              tone: _StatTone.danger,
            ),
            _HealthRow(
              icon: Icons.block_outlined,
              label: 'Unavailable',
              value: snapshot['unavailable'] ?? 0,
              tone: _StatTone.neutral,
            ),
            _HealthRow(
              icon: Icons.update_outlined,
              label: 'Unconfirmed (over 7 days)',
              value: snapshot['unconfirmed'] ?? 0,
              tone: _StatTone.neutral,
            ),
            _HealthRow(
              icon: Icons.event_busy_outlined,
              label: 'Expiring within 60 days',
              value: snapshot['expiring_within_60_days'] ?? 0,
              tone: _StatTone.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Counts may overlap. An item can be both low-stock and unconfirmed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card grid
// ---------------------------------------------------------------------------

enum _StatTone { success, warning, info, danger, neutral }

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = _StatTone.neutral,
  });

  final String label;
  final int value;
  final IconData icon;
  final _StatTone tone;
}

class _StatCardGrid extends StatelessWidget {
  const _StatCardGrid({required this.cards});

  final List<_StatCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 2 : 1;
        final gap = AppSpacing.md;
        final cardWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              _StatCard(data: c, width: cardWidth),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data, required this.width});

  final _StatCardData data;
  final double width;

  Color _iconBg(_StatTone tone) => switch (tone) {
        _StatTone.success => AppColors.primaryLight,
        _StatTone.warning => AppColors.warningLight,
        _StatTone.info => AppColors.infoLight,
        _StatTone.danger => AppColors.dangerLight,
        _StatTone.neutral => AppColors.neutralLight,
      };

  Color _iconColor(_StatTone tone) => switch (tone) {
        _StatTone.success => AppColors.primary,
        _StatTone.warning => AppColors.warning,
        _StatTone.info => AppColors.info,
        _StatTone.danger => AppColors.danger,
        _StatTone.neutral => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final bg = _iconBg(data.tone);
    final fg = _iconColor(data.tone);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(data.icon, size: 22, color: fg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

// ---------------------------------------------------------------------------
// Pending reservations card
// ---------------------------------------------------------------------------

class _PendingReservationsCard extends StatelessWidget {
  const _PendingReservationsCard({required this.reservations});

  final List<Map<String, dynamic>> reservations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: reservations.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'No pending reservations.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < reservations.length; i++) ...[
                  _PendingRow(reservation: reservations[i]),
                  if (i < reservations.length - 1)
                    const Divider(
                      height: 1,
                      color: AppColors.border,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                ],
              ],
            ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.reservation});

  final Map<String, dynamic> reservation;

  @override
  Widget build(BuildContext context) {
    final reference =
        reservation['reference_no']?.toString() ?? 'Unknown';
    final submittedAt =
        DateTime.tryParse(reservation['submitted_at']?.toString() ?? '');
    final formattedDate =
        submittedAt == null ? '—' : _formatDate(submittedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Reference icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Submitted: $formattedDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const StatusBadge('Pending', tone: BadgeTone.warning),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory health card
// ---------------------------------------------------------------------------

class _HealthRow {
  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final int value;
  final _StatTone tone;
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.items});

  final List<_HealthRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _HealthRowTile(row: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _HealthRowTile extends StatelessWidget {
  const _HealthRowTile({required this.row});

  final _HealthRow row;

  Color _fg(_StatTone tone) => switch (tone) {
        _StatTone.success => AppColors.primary,
        _StatTone.warning => AppColors.warning,
        _StatTone.info => AppColors.info,
        _StatTone.danger => AppColors.danger,
        _StatTone.neutral => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final fg = _fg(row.tone);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(row.icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            row.value.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: row.value > 0 ? fg : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.4,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load the dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDate(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String twoD(int v) => v.toString().padLeft(2, '0');
  return '${months[date.month - 1]} ${date.day}, '
      '${twoD(date.hour)}:${twoD(date.minute)}';
}


