import 'package:flutter/material.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/screens/driver/driver_common.dart';
import 'package:websupark/screens/driver/edit_vehicle_screen.dart';
import 'package:websupark/screens/driver/renewal_common.dart';
import 'package:websupark/theme/app_colors.dart';
import 'package:websupark/widgets/status_chip.dart';

// ---------------------------------------------------------------------------
// SAMPLE DATA (layout only)
// TODO: replace with repository data
// ---------------------------------------------------------------------------
// Details the driver can edit (see edit_vehicle_screen.dart).
const VehicleDetails _initialVehicle = VehicleDetails(
  name: 'Yana', // TODO: replace with repository data
  mobile: '+63 917 555 0148', // TODO: replace with repository data
  color: 'White', // TODO: replace with repository data
  type: 'Toyota Vios', // TODO: replace with repository data
);

// Details only the Parking Services Office can change.
const String _plateNumber = 'ABC-1234'; // TODO: replace with repository data
const String _passNumber = 'BLUE-025'; // TODO: replace with repository data
const String _passType = 'Blue Pass'; // TODO: replace with repository data
const String _passExpiration = 'March 31, 2027'; // TODO: replace with repository data
const String _assignedArea = 'Parking Area A'; // TODO: replace with repository data
const String _assignedSlot = 'A-025'; // TODO: replace with repository data

/// D5 My Vehicle: registration details, edit button and pass renewal.
/// It is a StatefulWidget because the details change after an edit.
class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  VehicleDetails _vehicle = _initialVehicle;

  // "White Toyota Vios" is built from the color and the type.
  String get _vehicleName => '${_vehicle.color} ${_vehicle.type}';

  // Rows of the Registration Details card, in the prototype's order.
  List<_Detail> get _details => [
        _Detail('Name', _vehicle.name),
        _Detail('Mobile number', _vehicle.mobile),
        const _Detail('Vehicle plate number', _plateNumber),
        _Detail('Vehicle color', _vehicle.color),
        _Detail('Vehicle type', _vehicle.type),
        const _Detail('Vehicle pass number', _passNumber),
        const _Detail('Pass type', _passType),
        const _Detail('Pass expiration', _passExpiration),
        const _Detail('Assigned parking area', _assignedArea),
        const _Detail('Assigned parking number', _assignedSlot),
      ];

  // Rows shown as "cannot be changed" on the edit screen.
  static const List<RenewalRow> _lockedRows = [
    RenewalRow('Plate number', _plateNumber),
    RenewalRow('Pass number', _passNumber),
    RenewalRow('Pass type', _passType),
    RenewalRow('Pass expiration', _passExpiration),
    RenewalRow('Assigned parking area', _assignedArea),
    RenewalRow('Assigned parking number', _assignedSlot),
  ];

  // Opens the edit screen and waits for it to close. If the driver saved,
  // the screen returns the new details; if they cancelled, it returns null.
  Future<void> _editVehicle() async {
    final updated = await Navigator.push<VehicleDetails>(
      context,
      MaterialPageRoute(
        builder: (_) => EditVehicleScreen(
          initial: _vehicle,
          lockedRows: _lockedRows,
        ),
      ),
    );

    if (updated == null || !mounted) return;
    setState(() => _vehicle = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle details updated.')),
    );
  }

  // Opens step 1 of the renewal flow (see renewal_payment_screen.dart).
  void _startRenewal() {
    Navigator.pushNamed(context, AppRoutes.driverRenewalPayment);
  }

  // "Learn more" explains when renewal is available.
  void _showLearnMore() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vehicle Pass Renewal'),
        content: const Text(
          'Renewal opens 30 days before your pass expires. '
          'Bring your current pass and registration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DriverPage(
      children: [
        DriverHeader(
          title: 'My Vehicle',
          subtitle: 'Registered driver and pass details',
          icon: Icons.edit_outlined,
          onIconTap: _editVehicle,
        ),
        const SizedBox(height: 16),
        _VehicleBanner(vehicleName: _vehicleName),
        const SizedBox(height: 20),
        const DriverSectionHeader(title: 'Registration Details'),
        const SizedBox(height: 10),
        _DetailsCard(details: _details),
        const SizedBox(height: 20),
        DriverSectionHeader(
          title: 'Vehicle Pass Renewal',
          action: 'Learn more',
          onActionTap: _showLearnMore,
        ),
        const SizedBox(height: 10),
        _RenewalTile(onTap: _startRenewal),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // The theme gives every button the blue style; this one is red.
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _startRenewal,
            child: const Text(
              'RENEW VEHICLE PASS',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Detail {
  const _Detail(this.label, this.value);

  final String label;
  final String value;
}

/// Dark blue card at the top: vehicle, plate, pass and Active chip.
class _VehicleBanner extends StatelessWidget {
  const _VehicleBanner({required this.vehicleName});

  final String vehicleName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          DriverIconBox(
            icon: Icons.directions_car_outlined,
            iconColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '$_plateNumber  ·  $_passNumber',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const StatusChip(label: 'ACTIVE', kind: StatusKind.success),
        ],
      ),
    );
  }
}

/// White card listing every registration detail, one per row.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.details});

  final List<_Detail> details;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < details.length; i++) ...[
              _DetailRow(detail: details[i]),
              // A thin line between rows, but not after the last one.
              if (i != details.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});

  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            detail.value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pale blue tile explaining when renewal opens.
class _RenewalTile extends StatelessWidget {
  const _RenewalTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.autorenew, size: 20, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Renew before $_passExpiration',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Renewal opens 30 days before expiration. Bring your current pass and registration.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
