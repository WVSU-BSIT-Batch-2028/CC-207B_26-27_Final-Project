import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/firestore_poke_service.dart';
import '../../../services/local_bus_tracking_service.dart';
import '../../../widgets/lookout_app_bar.dart';

class StartRideScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const StartRideScreen({super.key, this.onMenuPressed});

  @override
  State<StartRideScreen> createState() => _StartRideScreenState();
}

class _StartRideScreenState extends State<StartRideScreen> {
  static const _routes = <String, String>{
    'ungka-itgsi-loop': 'Ungka - ITGSI Loop',
    'tagbak-city-proper': 'Tagbak - City Proper',
    'mandurriao-jaro-plaza': 'Mandurriao - Jaro Plaza',
    'villa-beach-city-proper': 'Villa Beach - City Proper',
  };

  final _tracking = LocalBusTrackingService.instance;
  final _pokeService = FirestorePokeService.instance;
  String _selectedRouteId = _routes.keys.first;
  String _selectedPlate = '';
  TimeOfDay? _selectedDepartureTime;
  bool _isBusy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _isRideActive {
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

  Future<void> _selectDepartureTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedDepartureTime ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDepartureTime = selected);
    }
  }

  DateTime _departureDateTime() {
    final now = DateTime.now();
    final time = _selectedDepartureTime ?? TimeOfDay.fromDateTime(now);
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  Future<void> _toggleRide({required String uid, required String plate}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      if (_isRideActive) {
        await _tracking.stopRide(uid);
        _showMessage(
          'Ride ended. Trip was added to this session’s history.',
          'Info',
          NotifType.info,
        );
        return;
      }

      if (plate.isEmpty) {
        _showMessage(
          'Add a vehicle plate in My Vehicles first.',
          'Warning',
          NotifType.warning,
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activePlate': plate,
        'departureTime': Timestamp.fromDate(_departureDateTime()),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final hasLocationAccess = await _tracking.startRide(
        driverId: uid,
        plateNumber: plate,
        routeName: _routes[_selectedRouteId]!,
      );
      if (hasLocationAccess) {
        _showMessage(
          'Ride started. ${_tracking.serverConnectionStatus.value}.',
          'Ride started',
          NotifType.info,
        );
      } else {
        _showMessage(
          'Ride started locally, but GPS is unavailable and your vehicle '
              'location is not being shared.',
          'Location unavailable',
          NotifType.warning,
        );
      }
    } catch (error) {
      _showMessage(
        error is DriverTripSyncException
            ? error.toString()
            : 'Unable to ${_isRideActive ? 'end' : 'start'} ride: $error',
        error is DriverTripSyncException ? 'Analytics sync failed' : 'Error',
        NotifType.error,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message, String title, NotifType type) {
    if (!mounted) return;
    PopupNotif(message: message, title: title, type: type).show(context);
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

  Widget _buildRideContent(
    BuildContext context, {
    required String uid,
    required String activePlate,
    required List<String> plates,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedPlate = plates.contains(_selectedPlate)
        ? _selectedPlate
        : (plates.contains(activePlate)
              ? activePlate
              : (plates.isEmpty ? '' : plates.first));
    ActiveBus? currentBus;
    for (final bus in _tracking.activeBuses.value) {
      if (bus.driverId == uid) {
        currentBus = bus;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ride Management',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select an assigned vehicle and route, then start tracking your trip.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: const Text('Departure time'),
          subtitle: Text(
            _selectedDepartureTime?.format(context) ??
                'Automatic: current time',
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: _isBusy ? null : _selectDepartureTime,
                child: const Text('Choose'),
              ),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() => _selectedDepartureTime = null),
                child: const Text('Auto'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ride setup', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRouteId,
                  decoration: const InputDecoration(
                    labelText: 'Route',
                    prefixIcon: Icon(Icons.route),
                  ),
                  items: _routes.entries
                      .map(
                        (route) => DropdownMenuItem(
                          value: route.key,
                          child: Text(route.value),
                        ),
                      )
                      .toList(),
                  onChanged: _isRideActive
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedRouteId = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlate.isEmpty ? null : selectedPlate,
                  decoration: const InputDecoration(
                    labelText: 'Assigned vehicle',
                    prefixIcon: Icon(Icons.directions_bus),
                  ),
                  hint: const Text('No assigned vehicle'),
                  items: plates
                      .map(
                        (plate) =>
                            DropdownMenuItem(value: plate, child: Text(plate)),
                      )
                      .toList(),
                  onChanged: _isRideActive
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedPlate = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _toggleRide(uid: uid, plate: selectedPlate),
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: Loader.circular(
                              strokeWidth: 2,
                              showText: false,
                            ),
                          )
                        : Icon(_isRideActive ? Icons.stop : Icons.play_arrow),
                    label: Text(_isRideActive ? 'End Ride' : 'Start Ride'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              _isRideActive ? Icons.radio_button_checked : Icons.info_outline,
              color: _isRideActive ? colors.primary : colors.onSurfaceVariant,
            ),
            title: Text(_isRideActive ? 'Ride in progress' : 'Ready to start'),
            subtitle: Text(
              _isRideActive && currentBus != null
                  ? '${currentBus.routeName}\n${currentBus.plateNumber}'
                  : '${_routes[_selectedRouteId]}\n${selectedPlate.isEmpty ? 'No vehicle selected' : selectedPlate}',
            ),
            isThreeLine: true,
          ),
        ),
        if (selectedPlate.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Incoming passenger requests',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: _pokeService.streamIncomingPokes(selectedPlate),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Unable to load requests: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Loader.circular();
              }

              final requests = snapshot.data ?? const [];
              if (requests.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.notifications_none),
                    title: Text('No passenger requests for this vehicle.'),
                  ),
                );
              }

              return Column(
                children: requests.map((request) {
                  final data = request.data();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(data['fromName'] as String? ?? 'Commuter'),
                      subtitle: Text(
                        '${data['message'] as String? ?? 'Passenger request'}\n'
                        'Route: ${data['routeId'] as String? ?? 'Not specified'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Ride locations are tracked on this device. Trip history is kept for this app session.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'Start a Ride',
        onMenuPressed: widget.onMenuPressed,
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to manage driver rides.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load your driver profile: ${snapshot.error}',
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
                return _buildRideContent(
                  context,
                  uid: uid,
                  activePlate: profile?['activePlate'] as String? ?? '',
                  plates: _platesFrom(profile),
                );
              },
            ),
    );
  }
}
