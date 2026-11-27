import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';


//reusable widgets
import '../../../widgets/lookout_app_bar.dart';

//packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class SavedScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const SavedScreen({super.key, this.onMenuPressed});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  List<Map<String, dynamic>> _savedRidesFrom(dynamic value) {
    if (value is! Iterable) return [];
    return value
        .whereType<Map>()
        .map((ride) => Map<String, dynamic>.from(ride))
        .toList();
  }

  Future<void> _unsaveRide(String uid, String rideId) async {
    final userRef = _userRef(uid);
    try {
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw StateError('Your user profile could not be found.');
        }
        final rides = _savedRidesFrom(userSnapshot.data()?['savedRides']);
        rides.removeWhere((ride) => ride['rideId'] == rideId);
        transaction.update(userRef, {'savedRides': rides});
      });
      _showMessage('Ride removed from Saved Rides.', 'Info', NotifType.info);
    } catch (error) {
      _showMessage('Unable to unsave ride: $error', 'Error', NotifType.error);
    }
  }

  Future<void> _showRideDetails(
    BuildContext context,
    Map<String, dynamic> ride,
  ) async {
    final startedAt = _formatDate(ride['startedAt']);
    final endedAt = _formatDate(ride['endedAt']);
    final durationSeconds = ride['durationSeconds'] as int? ?? 0;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saved Ride Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route: ${ride['routeId'] ?? 'Unknown route'}'),
            const SizedBox(height: 8),
            Text('Vehicle: ${ride['toPlate'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Started: $startedAt'),
            const SizedBox(height: 8),
            Text('Ended: $endedAt'),
            const SizedBox(height: 8),
            Text(
              'Duration: ${durationSeconds ~/ 60}m ${durationSeconds % 60}s',
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

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Unavailable';
    return value.toDate().toLocal().toString();
  }

  void _showMessage(String message, String title, NotifType type) {
    if (!mounted) return;
    PopupNotif(message: message, title: title, type: type,).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _uid;

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'Saved Rides',
        onMenuPressed: widget.onMenuPressed,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Rides',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your favorited rides. Unfavorite a ride to remove it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Sign in to view your saved rides.'))
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _userRef(uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Error loading saved rides: ${snapshot.error}',
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Loader.circular();
                      }

                      final rides = _savedRidesFrom(
                        snapshot.data?.data()?['savedRides'],
                      );
                      if (rides.isEmpty) {
                        return const Center(
                          child: Text(
                            'No saved rides yet. Favorite a recent ride to save it.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          for (final ride in rides) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.route,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            ride['routeId'] as String? ??
                                                'Unknown route',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Unfavorite ride',
                                          onPressed: () {
                                            final rideId = ride['rideId'];
                                            if (rideId is String &&
                                                rideId.isNotEmpty) {
                                              _unsaveRide(uid, rideId);
                                            }
                                          },
                                          icon: const Icon(Icons.favorite),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Vehicle: ${ride['toPlate'] ?? 'N/A'}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ended: ${_formatDate(ride['endedAt'])}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            _showRideDetails(context, ride),
                                        child: const Text('See More'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
