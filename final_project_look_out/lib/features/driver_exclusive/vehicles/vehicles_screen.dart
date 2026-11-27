import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/confirmation_dialog.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/local_bus_tracking_service.dart';
import '../../../widgets/lookout_app_bar.dart';

class VehiclesScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const VehiclesScreen({super.key, this.onMenuPressed});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _tracking = LocalBusTrackingService.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _hasActiveRide {
    final uid = _uid;
    return uid != null &&
        _tracking.activeBuses.value.any(
          (bus) => bus.driverId == uid && bus.isActive,
        );
  }

  @override
  void initState() {
    super.initState();
    _tracking.activeBuses.addListener(_handleTrackingChanged);
  }

  @override
  void dispose() {
    _tracking.activeBuses.removeListener(_handleTrackingChanged);
    super.dispose();
  }

  void _handleTrackingChanged() {
    if (mounted) setState(() {});
  }

  List<String> _platesFrom(Map<String, dynamic>? profile) {
    final rawPlates = profile?['plates'];
    final plates = rawPlates is Iterable
        ? rawPlates.whereType<String>().toList()
        : <String>[];
    final activePlate = profile?['activePlate'];
    if (activePlate is String &&
        activePlate.isNotEmpty &&
        !plates.contains(activePlate)) {
      plates.insert(0, activePlate);
    }
    return plates;
  }

  Future<void> _addPlate(String uid, String input) async {
    final plate = input.trim().toUpperCase();
    if (plate.isEmpty) {
      throw ArgumentError('Enter a vehicle plate number.');
    }

    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw StateError('Driver profile not found.');
      }

      final profile = snapshot.data() ?? <String, dynamic>{};
      final rawPlates = profile['plates'];
      final plates = rawPlates is Iterable
          ? rawPlates.whereType<String>().toList()
          : <String>[];
      if (plates.any((existing) => existing.toUpperCase() == plate)) {
        throw StateError('That vehicle is already on your list.');
      }

      final activePlate = profile['activePlate'];
      final updates = <String, dynamic>{
        'plates': [...plates, plate],
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (activePlate is! String || activePlate.isEmpty) {
        updates['activePlate'] = plate;
      }
      transaction.update(userRef, updates);
    });
  }

  Future<void> _setActivePlate(String uid, String plate) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw StateError('Driver profile not found.');
      }

      final rawPlates = snapshot.data()?['plates'];
      final plates = rawPlates is Iterable
          ? rawPlates.whereType<String>().toList()
          : <String>[];
      if (!plates.contains(plate)) {
        throw StateError('This vehicle is no longer assigned to your account.');
      }
      transaction.update(userRef, {
        'activePlate': plate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _removePlate(String uid, String plate) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw StateError('Driver profile not found.');
      }

      final profile = snapshot.data() ?? <String, dynamic>{};
      final rawPlates = profile['plates'];
      final plates = rawPlates is Iterable
          ? rawPlates.whereType<String>().toList()
          : <String>[];
      final remainingPlates = plates.where((item) => item != plate).toList();
      final activePlate = profile['activePlate'];

      transaction.update(userRef, {
        'plates': remainingPlates,
        'activePlate': activePlate == plate
            ? (remainingPlates.isEmpty ? '' : remainingPlates.first)
            : activePlate as String? ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _showAddPlateDialog(String uid) async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) => const _AddVehicleDialog(),
    );

    if (input == null || !mounted) return;
    try {
      await _addPlate(uid, input);
      _showMessage('Vehicle added.', 'Info', NotifType.info);
    } catch (error) {
      _showMessage('Unable to add vehicle: $error', 'Error', NotifType.error);
    }
  }

  Future<void> _confirmRemove(String uid, String plate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Remove vehicle?',
        content: 'Remove $plate from your assigned vehicles?',
        confirmText: 'Remove',
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_hasActiveRide) {
      _showMessage('End your active ride before removing a vehicle.', 'Warning', NotifType.warning);
      return;
    }

    try {
      await _removePlate(uid, plate);
      _showMessage('Vehicle removed.', 'Info', NotifType.info);
    } catch (error) {
      _showMessage('Unable to remove vehicle: $error', 'Error', NotifType.error);
    }
  }

  void _showMessage(String message, String title, NotifType type) {
    if (!mounted) return;
    PopupNotif(message: message, title: title, type: type).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'My Vehicles',
        onMenuPressed: widget.onMenuPressed,
        actions: [
          if (uid != null)
            IconButton(
              tooltip: 'Add vehicle',
              onPressed: _hasActiveRide ? null : () => _showAddPlateDialog(uid),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to manage your vehicles.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load your vehicles: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Loader.circular();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Driver profile not found.'));
                }

                final profile = snapshot.data!.data();
                final plates = _platesFrom(profile);
                final activePlate = profile?['activePlate'] as String? ?? '';

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Assigned vehicles',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the vehicle used when you start a ride.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (_hasActiveRide) ...[
                      const SizedBox(height: 12),
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text(
                            'End your active ride before changing vehicles.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (plates.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.directions_bus_outlined,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              const Text('No assigned vehicles yet.'),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _hasActiveRide
                                    ? null
                                    : () => _showAddPlateDialog(uid),
                                icon: const Icon(Icons.add),
                                label: const Text('Add vehicle'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...plates.map((plate) {
                        final isActive = plate == activePlate;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              foregroundColor: isActive
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                              child: const Icon(Icons.directions_bus),
                            ),
                            title: Text(
                              plate,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              isActive ? 'Selected for rides' : 'Assigned',
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !_hasActiveRide,
                              onSelected: (action) async {
                                try {
                                  if (action == 'select') {
                                    await _setActivePlate(uid, plate);
                                    _showMessage('Active vehicle updated.', 'Info', NotifType.info);
                                  } else if (action == 'remove') {
                                    await _confirmRemove(uid, plate);
                                  }
                                } catch (error) {
                                  _showMessage(
                                    'Unable to update vehicle: $error',
                                    'Error',
                                    NotifType.error
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isActive)
                                  const PopupMenuItem(
                                    value: 'select',
                                    child: Text('Set as active'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove vehicle'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _hasActiveRide
                              ? null
                              : () => _showAddPlateDialog(uid),
                          icon: const Icon(Icons.add),
                          label: const Text('Add vehicle'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Vehicle assignments are saved to your driver profile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _AddVehicleDialog extends StatefulWidget {
  const _AddVehicleDialog();

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a vehicle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Plate number',
          hintText: 'e.g. ABC-1234',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
