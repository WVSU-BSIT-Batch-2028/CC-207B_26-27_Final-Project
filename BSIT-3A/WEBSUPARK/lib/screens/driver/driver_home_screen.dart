import 'package:flutter/material.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/theme/app_colors.dart';
import 'package:websupark/widgets/status_chip.dart';

// ---------------------------------------------------------------------------
// SAMPLE DATA (layout only)
// Every value in this block is a placeholder from the prototype.
// TODO: replace with repository data
// ---------------------------------------------------------------------------
const String _driverName = 'Yana'; // TODO: replace with repository data
const String _vehicleName = 'White Toyota Vios'; // TODO: replace with repository data
const String _plateNumber = 'ABC-1234'; // TODO: replace with repository data
const String _passNumber = 'BLUE-025'; // TODO: replace with repository data
const String _assignedAreaName = 'Parking Area A'; // TODO: replace with repository data
const String _assignedSlot = 'A-025'; // TODO: replace with repository data
const int _capacity = 50; // TODO: replace with repository data
const int _occupied = 42; // TODO: replace with repository data
const int _availableSpaces = _capacity - _occupied;

// TODO: replace with repository data
const List<_AreaAvailability> _otherAreas = [
  _AreaAvailability(name: 'Area A', availableSpaces: 8, isAssigned: true),
  _AreaAvailability(name: 'Area B', availableSpaces: 0),
  _AreaAvailability(name: 'Area C', availableSpaces: 17),
  _AreaAvailability(name: 'Area D', availableSpaces: 3),
];

/// One row of the "Other Areas" list.
class _AreaAvailability {
  const _AreaAvailability({
    required this.name,
    required this.availableSpaces,
    this.isAssigned = false,
  });

  final String name;
  final int availableSpaces;

  /// True for the driver's own area, which is highlighted in the list.
  final bool isAssigned;
}

// ---------------------------------------------------------------------------
// STATUS RULES
// The status is calculated from the free spaces, never typed by hand,
// so the label and the color can never disagree with the number.
// ---------------------------------------------------------------------------
StatusKind _kindFor(int availableSpaces) {
  if (availableSpaces == 0) return StatusKind.danger; // Full
  if (availableSpaces <= 3) return StatusKind.warning; // Almost Full
  return StatusKind.success; // Available
}

String _labelFor(int availableSpaces) {
  if (availableSpaces == 0) return 'Full';
  if (availableSpaces <= 3) return 'Almost Full';
  return 'Available';
}

Color _colorFor(StatusKind kind) => switch (kind) {
      StatusKind.success => AppColors.success,
      StatusKind.warning => AppColors.warning,
      StatusKind.danger => AppColors.danger,
      StatusKind.neutral => AppColors.textMuted,
    };

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

// Small gray caps label used above some values, e.g. "YOUR VEHICLE".
const TextStyle _labelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
  color: AppColors.textMuted,
);

/// D1 Home: greeting, the driver's vehicle, and live parking availability.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: 16),
          const _VehicleCard(),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: 'Parking Availability',
            action: 'Live status',
          ),
          const SizedBox(height: 10),
          const _AssignedAreaCard(),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Other Areas', action: 'Updated now'),
          const SizedBox(height: 10),
          const _OtherAreasCard(),
        ],
      ),
    );
  }
}

/// Greeting on the left, notification bell on the right.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $_driverName!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'University Parking Services',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        _IconBox(
          icon: Icons.notifications_none,
          onTap: () => Navigator.pushNamed(context, AppRoutes.driverAlerts),
        ),
      ],
    );
  }
}

/// Rounded pale-blue square holding an icon (bell, car, ...).
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap; // null = not tappable

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Title on the left, small blue link-style text on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// "YOUR VEHICLE" card with the plate, pass and an Active chip.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const _IconBox(icon: Icons.directions_car_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR VEHICLE', style: _labelStyle),
                  SizedBox(height: 2),
                  Text(
                    _vehicleName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '$_plateNumber  •  $_passNumber  •  $_assignedAreaName',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const StatusChip(label: 'ACTIVE', kind: StatusKind.success),
          ],
        ),
      ),
    );
  }
}

/// The driver's own area, with free spaces, occupancy and a progress bar.
class _AssignedAreaCard extends StatelessWidget {
  const _AssignedAreaCard();

  @override
  Widget build(BuildContext context) {
    final kind = _kindFor(_availableSpaces);
    final color = _colorFor(kind);

    return Card(
      margin: EdgeInsets.zero,
      // Blue outline marks this as "your" area.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: area name and status chip.
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR ASSIGNED AREA', style: _labelStyle),
                      SizedBox(height: 2),
                      Text(
                        _assignedAreaName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: _labelFor(_availableSpaces).toUpperCase(), kind: kind),
              ],
            ),
            const SizedBox(height: 12),

            // Middle row: big free-space number, and occupied / capacity.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$_availableSpaces',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'spaces\ncurrently\navailable',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_occupied / $_capacity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'occupied',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar: how full the area is.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _occupied / _capacity,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: color,
              ),
            ),
            const SizedBox(height: 12),

            // Bottom strip: the driver's own slot.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_parking, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Your Assigned Area:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    _assignedSlot,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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

/// List of every area with its free spaces and status.
class _OtherAreasCard extends StatelessWidget {
  const _OtherAreasCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (final area in _otherAreas) _AreaRow(area: area),
          ],
        ),
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area});

  final _AreaAvailability area;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(_kindFor(area.availableSpaces));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        // The driver's own area gets a pale-blue background.
        color: area.isAssigned
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Colored status dot.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              area.name,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${area.availableSpaces} spaces',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _labelFor(area.availableSpaces),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
