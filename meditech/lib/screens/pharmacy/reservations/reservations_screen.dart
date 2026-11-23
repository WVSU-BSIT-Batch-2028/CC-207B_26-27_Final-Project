import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'reservation_details_drawer.dart';

import '../../../models/branch_reservation.dart';
import '../../../providers/branch_reservation_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_data_table.dart';
import '../../../widgets/tablet/tablet_filter_panel.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

enum RequestedDateFilter {
  anyTime,
  today,
  last7Days,
}

// Tablet screen displaying reservations with filters, search, and view action (Ph-12 & Ph-13)
class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({
    super.key,
    this.onViewReservation,
  });

  final ValueChanged<BranchReservation>? onViewReservation;

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  String _searchQuery = '';
  final Set<String> _selectedStatuses = {};
  RequestedDateFilter _dateFilter = RequestedDateFilter.anyTime;
  bool _onlyRx = false;
  bool _showFilters = false;

  static const _statusOptions = [
    'pending',
    'confirmed',
    'ready_for_pickup',
    'completed',
    'rejected',
    'cancelled',
    'expired',
  ];

  static const _statusLabels = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'ready_for_pickup': 'Ready for Pickup',
    'completed': 'Completed',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };

  int get _activeFilterCount =>
      _selectedStatuses.length +
      (_dateFilter != RequestedDateFilter.anyTime ? 1 : 0) +
      (_onlyRx ? 1 : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(branchReservationsProvider.notifier).refresh();
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedStatuses.clear();
      _dateFilter = RequestedDateFilter.anyTime;
      _onlyRx = false;
    });
  }

  bool _matchesDateFilter(DateTime submittedAt, RequestedDateFilter filter) {
    if (filter == RequestedDateFilter.anyTime) return true;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (filter == RequestedDateFilter.today) {
      return submittedAt.isAfter(todayStart);
    }
    if (filter == RequestedDateFilter.last7Days) {
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      return submittedAt.isAfter(sevenDaysAgo);
    }
    return true;
  }

  List<BranchReservation> _filterReservations(List<BranchReservation> all) {
    final query = _searchQuery.trim().toLowerCase();
    return all.where((res) {
      if (query.isNotEmpty) {
        final matchesRef = res.referenceNo.toLowerCase().contains(query);
        final matchesName = res.customerName.toLowerCase().contains(query);
        if (!matchesRef && !matchesName) return false;
      }

      if (_selectedStatuses.isNotEmpty &&
          !_selectedStatuses.contains(res.status)) {
        return false;
      }

      if (!_matchesDateFilter(res.submittedAt, _dateFilter)) {
        return false;
      }

      if (_onlyRx && !res.hasRx) {
        return false;
      }

      return true;
    }).toList();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) {
      return 'Today, $timeStr';
    }
    return '${DateFormat('MMM d').format(dt)}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(branchReservationsProvider);
    final selectedId = ref.watch(selectedReservationIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                AsyncView<List<BranchReservation>>(
                  value: reservationsAsync,
                  onRetry: () => ref.read(branchReservationsProvider.notifier).refresh(),
                  builder: (allReservations) {
                    final filtered = _filterReservations(allReservations);

                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header title & count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reservations',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${filtered.length} of ${allReservations.length} reservations',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Table
                          Expanded(
                            child: TabletDataTable<BranchReservation>(
                              searchHint: 'Reference or patient name',
                              searchQuery: _searchQuery,
                              onSearchChanged: (q) => setState(() => _searchQuery = q),
                              totalCount: allReservations.length,
                              filteredCount: filtered.length,
                              countLabel: 'reservations',
                              activeFilterCount: _activeFilterCount,
                              onFiltersTap: () =>
                                  setState(() => _showFilters = !_showFilters),
                              items: filtered,
                              columns: const [
                                TabletColumn(
                                  title: 'REFERENCE',
                                  priority: TabletColumnPriority.high,
                                  width: 170,
                                ),
                                TabletColumn(
                                  title: 'PATIENT',
                                  priority: TabletColumnPriority.high,
                                  width: 190,
                                ),
                                TabletColumn(
                                  title: 'MEDICINES',
                                  priority: TabletColumnPriority.high,
                                  width: 220,
                                ),
                                TabletColumn(
                                  title: 'REQUESTED',
                                  priority: TabletColumnPriority.medium,
                                  width: 170,
                                ),
                                TabletColumn(
                                  title: 'STATUS',
                                  priority: TabletColumnPriority.high,
                                  width: 150,
                                ),
                                TabletColumn(
                                  title: 'VIEW',
                                  priority: TabletColumnPriority.high,
                                  width: 80,
                                  alignment: Alignment.center,
                                ),
                              ],
                              rowBuilder: (context, item, index) {
                                final isSelected = item.id == selectedId;
                                return [
                                  // Reference column
                                  Text(
                                    item.referenceNo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.text,
                                    ),
                                  ),

                                  // Patient column with optional Rx badge
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.customerName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (item.hasRx) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        const StatusBadge.rx(),
                                      ],
                                    ],
                                  ),

                                  // Medicines summary
                                  Text(
                                    item.medicinesSummary,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),

                                  // Requested date/time
                                  Text(
                                    _formatTimestamp(item.submittedAt),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),

                                  // Status badge
                                  StatusBadge.reservation(item.status),

                                  // View action button
                                  IconButton(
                                    icon: Icon(
                                      isSelected
                                          ? Icons.visibility
                                          : Icons.visibility_outlined,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    tooltip: 'View details',
                                    onPressed: () {
                                      ref
                                          .read(selectedReservationIdProvider.notifier)
                                          .select(item.id);
                                      widget.onViewReservation?.call(item);
                                    },
                                  ),
                                ];
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Filters popover panel (Ph-13)
                if (_showFilters)
                  Positioned(
                    top: 80,
                    right: AppSpacing.lg,
                    child: _buildFiltersPanel(reservationsAsync.value ?? []),
                  ),
              ],
            ),
          ),

          // Slide-in right drawer when reservation is selected (Ph-14, Ph-17, Ph-18, Ph-37)
          if (selectedId != null)
            ReservationDetailsDrawer(
              reservationId: selectedId,
              onClose: () =>
                  ref.read(selectedReservationIdProvider.notifier).select(null),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(List<BranchReservation> allReservations) {
    // Count occurrences per status for display in filter panel
    final statusCounts = <String, int>{};
    for (final opt in _statusOptions) {
      statusCounts[opt] =
          allReservations.where((r) => r.status == opt).length;
    }

    return TabletFilterPanel(
      title: 'Filter reservations',
      activeFilterCount: _activeFilterCount,
      onReset: _resetFilters,
      onApply: () => setState(() => _showFilters = false),
      onClose: () => setState(() => _showFilters = false),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Status Checkboxes with counts (Ph-13)
          ..._statusOptions.map((statusKey) {
            final isChecked = _selectedStatuses.contains(statusKey);
            final count = statusCounts[statusKey] ?? 0;
            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _selectedStatuses.remove(statusKey);
                  } else {
                    _selectedStatuses.add(statusKey);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedStatuses.add(statusKey);
                            } else {
                              _selectedStatuses.remove(statusKey);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _statusLabels[statusKey] ?? statusKey,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),
          const Text(
            'REQUESTED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Requested date filter chips
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any time'),
                selected: _dateFilter == RequestedDateFilter.anyTime,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _dateFilter == RequestedDateFilter.anyTime
                      ? Colors.white
                      : AppColors.text,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(
                    () => _dateFilter = RequestedDateFilter.anyTime),
              ),
              ChoiceChip(
                label: const Text('Today'),
                selected: _dateFilter == RequestedDateFilter.today,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _dateFilter == RequestedDateFilter.today
                      ? Colors.white
                      : AppColors.text,
                  fontSize: 12,
                ),
                onSelected: (_) =>
                    setState(() => _dateFilter = RequestedDateFilter.today),
              ),
              ChoiceChip(
                label: const Text('Last 7 days'),
                selected: _dateFilter == RequestedDateFilter.last7Days,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _dateFilter == RequestedDateFilter.last7Days
                      ? Colors.white
                      : AppColors.text,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(
                    () => _dateFilter = RequestedDateFilter.last7Days),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          // Only reservations with Rx medicines toggle
          InkWell(
            onTap: () => setState(() => _onlyRx = !_onlyRx),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _onlyRx,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) =>
                          setState(() => _onlyRx = val ?? false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'Only reservations with Rx medicines',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
