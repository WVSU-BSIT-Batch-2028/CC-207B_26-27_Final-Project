import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/local_bus_tracking_service.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/lookout_app_bar.dart';
import '../../../widgets/popup_notif.dart';

class TripsScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const TripsScreen({super.key, this.onMenuPressed});

  List<DriverTrip> _mergeTrips({
    required String uid,
    required List<DriverTrip> localTrips,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> remoteDocs,
  }) {
    final tripsById = <String, DriverTrip>{};

    for (final doc in remoteDocs) {
      final data = doc.data();
      final startedAt = data['startedAt'];
      final endedAt = data['endedAt'];
      if (startedAt is! Timestamp || endedAt is! Timestamp) continue;

      final trip = DriverTrip(
        driverId: data['driverUid'] as String? ?? uid,
        plateNumber: data['plateNumber'] as String? ?? 'Unknown vehicle',
        routeName: data['routeName'] as String? ?? 'Unknown route',
        startedAt: startedAt.toDate(),
        endedAt: endedAt.toDate(),
        tripId: doc.id,
      );
      tripsById[trip.resolvedId] = trip;
    }

    for (final trip in localTrips) {
      if (trip.driverId != uid) continue;
      tripsById.putIfAbsent(trip.resolvedId, () => trip);
    }

    final merged = tripsById.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged;
  }

  Future<void> _showTripDetails(BuildContext context, DriverTrip trip) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: const Icon(Icons.route),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trip.routeName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripDetailRow(label: 'Vehicle', value: trip.plateNumber),
            const SizedBox(height: 10),
            _TripDetailRow(
              label: 'Started',
              value: _formatReadableDateTime(trip.startedAt),
            ),
            const SizedBox(height: 10),
            _TripDetailRow(
              label: 'Ended',
              value: _formatReadableDateTime(trip.endedAt),
            ),
            const SizedBox(height: 10),
            _TripDetailRow(
              label: 'Duration',
              value: _formatDuration(trip.duration),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip(
    BuildContext context,
    LocalBusTrackingService tracking,
    DriverTrip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: 'Delete Trip?',
        content: 'Delete this trip for ${trip.plateNumber}?',
        confirmText: 'Delete',
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await tracking.deleteTrip(trip);
      if (!context.mounted) return;
      PopupNotif(
        title: 'Deleted',
        message: 'Trip removed from history.',
        type: NotifType.info,
      ).show(context);
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      PopupNotif(
        title: 'Error',
        message: 'Unable to delete trip: ${error.message ?? error.code}',
        type: NotifType.error,
      ).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final tracking = LocalBusTrackingService.instance;

    return Scaffold(
      appBar: LookOutAppBar(title: 'My Trips', onMenuPressed: onMenuPressed),
      body: uid == null
          ? const Center(child: Text('Sign in to view your trips.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('driver_trips')
                  .where('driverUid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, remoteSnapshot) {
                if (remoteSnapshot.connectionState == ConnectionState.waiting &&
                    !remoteSnapshot.hasData &&
                    tracking.completedTrips.value.isEmpty) {
                  return const Loader.circular();
                }

                final remoteDocs = remoteSnapshot.hasError
                    ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
                    : (remoteSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);

                return ValueListenableBuilder<List<DriverTrip>>(
                  valueListenable: tracking.completedTrips,
                  builder: (context, localTrips, _) {
                    final trips = _mergeTrips(
                      uid: uid,
                      localTrips: localTrips,
                      remoteDocs: remoteDocs,
                    );
                    final totalDuration = trips.fold<Duration>(
                      Duration.zero,
                      (total, trip) => total + trip.duration,
                    );

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'Trip History',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review your recent trips.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _TripSummaryCard(
                              title: 'Total trips',
                              value: '${trips.length}',
                              icon: Icons.route_outlined,
                            ),
                            _TripSummaryCard(
                              title: 'Time on road',
                              value: _formatDuration(totalDuration),
                              icon: Icons.schedule,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Recent trips', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (trips.isEmpty)
                          const Card(
                            child: ListTile(
                              leading: Icon(Icons.route_outlined),
                              title: Text('No trips recorded yet.'),
                              subtitle: Text(
                                'Start and end a ride to record it here.',
                              ),
                            ),
                          )
                        else
                          ...trips.map(
                            (trip) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TripCard(
                                trip: trip,
                                onViewMore: () =>
                                    _showTripDetails(context, trip),
                                onDelete: () =>
                                    _deleteTrip(context, tracking, trip),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onViewMore,
    required this.onDelete,
  });

  final DriverTrip trip;
  final VoidCallback onViewMore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: const Icon(Icons.route),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trip.routeName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Trip options',
                  onSelected: (action) {
                    if (action == 'viewMore') onViewMore();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'viewMore',
                      child: Text('View more'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Vehicle: ${trip.plateNumber}'),
            const SizedBox(height: 4),
            Text('Started: ${_formatReadableDateTime(trip.startedAt)}'),
          ],
        ),
      ),
    );
  }
}

class _TripDetailRow extends StatelessWidget {
  const _TripDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.sizeOf(context).width - 52) / 2;

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatReadableDateTime(DateTime value) {
  final local = value.toLocal();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $period';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
