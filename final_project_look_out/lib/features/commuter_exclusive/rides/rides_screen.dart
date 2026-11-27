import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/confirmation_dialog.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/local_bus_tracking_service.dart';
import '../../../widgets/floating_button.dart';
import '../../../widgets/lookout_app_bar.dart';

class _RideTrackingViewState {
  const _RideTrackingViewState({
    this.message,
    this.nearbyPlate,
    this.pendingPlate,
    this.notificationId,
    this.notificationTitle,
    this.notificationMessage,
  });

  final String? message;
  final String? nearbyPlate;
  final String? pendingPlate;
  final String? notificationId;
  final String? notificationTitle;
  final String? notificationMessage;
}

class _CommuterRideTracker {
  _CommuterRideTracker._();

  static final _CommuterRideTracker instance = _CommuterRideTracker._();

  static const double _entryRadiusMeters = 15;
  static const double _exitRadiusMeters = 25;
  static const Duration _entryDwell = Duration(seconds: 30);
  static const Duration _exitDwell = Duration(seconds: 20);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalBusTrackingService _busTracking = LocalBusTrackingService.instance;
  final Distance _distance = const Distance();
  final ValueNotifier<_RideTrackingViewState> viewState = ValueNotifier(
    const _RideTrackingViewState(),
  );

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _entryTimer;
  Timer? _exitTimer;
  Future<void>? _startFuture;
  LatLng? _commuterPosition;
  Map<String, dynamic>? _activeSession;
  String? _candidateDriverId;
  DateTime? _candidateSince;
  DateTime? _outsideSince;
  String? _uid;
  bool _busListenerAttached = false;
  bool _activeSessionLoaded = false;
  bool _updatingSession = false;
  bool _updateRequested = false;
  bool _locationStartupInProgress = false;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> ensureStarted(String? uid) async {
    _authSubscription ??= _auth.authStateChanges().listen(
      _onAuthChanged,
      onError: (Object error) =>
          _setMessage('Authentication tracking failed: $error'),
    );
    if (uid == null) {
      if (_uid != null) await _switchUser(null);
      return;
    }
    if (_uid == uid) {
      if (!_activeSessionLoaded) {
        await _loadActiveRideSession(uid);
      }
      final starting = _startFuture;
      if (starting != null) {
        await starting;
      } else {
        await _startLocationTracking();
      }
      return;
    }

    await _switchUser(uid);
  }

  Future<void> _switchUser(String? uid) async {
    await _stopTracking();
    _uid = uid;
    if (uid == null) return;

    await _loadActiveRideSession(uid);
    _busTracking.activeBuses.addListener(_onBusesChanged);
    _busListenerAttached = true;
    _busTracking.connectToServer();

    final startFuture = _startLocationTracking();
    _startFuture = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startFuture, startFuture)) _startFuture = null;
    }
  }

  void _onAuthChanged(User? user) {
    if (user?.uid == _uid) return;
    unawaited(_switchUser(user?.uid));
  }

  Future<void> _stopTracking() async {
    if (_busListenerAttached) {
      _busTracking.activeBuses.removeListener(_onBusesChanged);
      _busListenerAttached = false;
    }
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _entryTimer?.cancel();
    _entryTimer = null;
    _exitTimer?.cancel();
    _exitTimer = null;
    _commuterPosition = null;
    _activeSession = null;
    _candidateDriverId = null;
    _candidateSince = null;
    _outsideSince = null;
    _activeSessionLoaded = false;
    _updatingSession = false;
    _updateRequested = false;
    _setViewState(const _RideTrackingViewState());
  }

  Future<void> _loadActiveRideSession(String uid) async {
    try {
      final snapshot = await _userRef(uid).get();
      if (!snapshot.exists) {
        throw StateError('Your user profile could not be found.');
      }
      final value = snapshot.data()?['activeRideSession'];
      _activeSession = value is Map ? Map<String, dynamic>.from(value) : null;
      _activeSessionLoaded = true;
      final plate = _activeSession?['toPlate'];
      _setViewState(
        _RideTrackingViewState(nearbyPlate: plate is String ? plate : null),
      );
    } catch (error) {
      _activeSessionLoaded = false;
      _setMessage('Unable to load your current ride: $error');
    }
  }

  Future<void> _startLocationTracking() async {
    if (_locationStartupInProgress || _uid == null) return;
    _locationStartupInProgress = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setMessage('Allow location access to detect nearby PUVs.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setMessage('Turn on location services to detect nearby PUVs.');
        return;
      }

      await _refreshLocation();
      _positionSubscription ??=
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen(
            (position) {
              _commuterPosition = LatLng(position.latitude, position.longitude);
              unawaited(_updateRideSession());
            },
            onError: (Object error) {
              _setMessage('Location tracking failed: $error');
            },
          );
    } catch (error) {
      _setMessage('Unable to access your location: $error');
    } finally {
      _locationStartupInProgress = false;
    }
  }

  Future<bool> refreshLocation() async {
    await _startLocationTracking();
    final state = viewState.value;
    return state.message == null &&
        (state.nearbyPlate != null || state.pendingPlate != null);
  }

  Future<void> _refreshLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _commuterPosition = LatLng(position.latitude, position.longitude);
    _setMessage(null);
    await _updateRideSession();
  }

  void _setMessage(String? message) {
    final state = viewState.value;
    _setViewState(
      _RideTrackingViewState(
        message: message,
        nearbyPlate: state.nearbyPlate,
        pendingPlate: state.pendingPlate,
        notificationId: state.notificationId,
        notificationTitle: state.notificationTitle,
        notificationMessage: state.notificationMessage,
      ),
    );
  }

  void _setViewState(_RideTrackingViewState state) {
    viewState.value = state;
  }

  void _onBusesChanged() {
    unawaited(_updateRideSession());
  }

  List<ActiveBus> get _trackedBuses => _busTracking.activeBuses.value;

  ActiveBus? _nearestBusWithin(LatLng position, double radiusMeters) {
    final candidates =
        _trackedBuses
            .where(
              (bus) =>
                  bus.isActive &&
                  _distance.as(LengthUnit.Meter, position, bus.position) <=
                      radiusMeters,
            )
            .toList()
          ..sort(
            (first, second) => _distance
                .as(LengthUnit.Meter, position, first.position)
                .compareTo(
                  _distance.as(LengthUnit.Meter, position, second.position),
                ),
          );
    if (_candidateDriverId != null) {
      for (final bus in candidates) {
        if (bus.driverId == _candidateDriverId) return bus;
      }
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  void _scheduleEntryCheck(Duration delay) {
    _entryTimer?.cancel();
    _entryTimer = Timer(delay, () {
      _entryTimer = null;
      unawaited(_updateRideSession());
    });
  }

  void _scheduleExitCheck(Duration delay) {
    _exitTimer?.cancel();
    _exitTimer = Timer(delay, () {
      _exitTimer = null;
      unawaited(_updateRideSession());
    });
  }

  void _clearEntryCandidate() {
    _entryTimer?.cancel();
    _entryTimer = null;
    _candidateDriverId = null;
    _candidateSince = null;
  }

  void _clearExitCandidate() {
    _exitTimer?.cancel();
    _exitTimer = null;
    _outsideSince = null;
  }

  void _setRideStatus({String? nearbyPlate, String? pendingPlate}) {
    final state = viewState.value;
    _setViewState(
      _RideTrackingViewState(
        message: state.message,
        nearbyPlate: nearbyPlate,
        pendingPlate: pendingPlate,
        notificationId: state.notificationId,
        notificationTitle: state.notificationTitle,
        notificationMessage: state.notificationMessage,
      ),
    );
  }

  void _setRideNotification({
    required String id,
    required String title,
    required String message,
    String? nearbyPlate,
  }) {
    final state = viewState.value;
    _setViewState(
      _RideTrackingViewState(
        message: state.message,
        nearbyPlate: nearbyPlate,
        notificationId: id,
        notificationTitle: title,
        notificationMessage: message,
      ),
    );
  }

  Future<bool> _beginRideSession(String uid, ActiveBus bus) async {
    final rideId = _db.collection('rides').doc().id;
    final startedAt = Timestamp.now();
    final session = <String, dynamic>{
      'rideId': rideId,
      'driverId': bus.driverId,
      'toPlate': bus.plateNumber,
      'routeId': bus.routeName,
      'startedAt': startedAt,
    };
    final created = await _db.runTransaction<bool>((transaction) async {
      final userRef = _userRef(uid);
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('Your user profile could not be found.');
      }
      final existingSession = userSnapshot.data()?['activeRideSession'];
      if (existingSession is Map) return false;
      transaction.update(userRef, {'activeRideSession': session});
      return true;
    });
    if (created) _activeSession = session;
    return created;
  }

  Future<bool> _completeRideSession(
    String uid,
    Map<String, dynamic> session,
  ) async {
    final storedRideId = session['rideId'];
    final rideId = storedRideId is String && storedRideId.isNotEmpty
        ? storedRideId
        : _db.collection('rides').doc().id;
    return _db.runTransaction<bool>((transaction) async {
      final userRef = _userRef(uid);
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('Your user profile could not be found.');
      }
      final currentValue = userSnapshot.data()?['activeRideSession'];
      if (currentValue is! Map) return false;
      final currentSession = Map<String, dynamic>.from(currentValue);
      final currentRideId = currentSession['rideId'];
      if (currentRideId is String &&
          storedRideId is String &&
          currentRideId != storedRideId) {
        return false;
      }

      final endedAt = Timestamp.now();
      final startedAt = currentSession['startedAt'];
      final startedDate = startedAt is Timestamp
          ? startedAt.toDate()
          : endedAt.toDate();
      final rideRef = _db.collection('rides').doc(rideId);
      transaction.set(rideRef, {
        'id': rideId,
        'commuterUid': uid,
        'driverId': currentSession['driverId'],
        'toPlate': currentSession['toPlate'],
        'routeId': currentSession['routeId'],
        'startedAt': startedAt,
        'endedAt': endedAt,
        'durationSeconds': endedAt.toDate().difference(startedDate).inSeconds,
        'status': 'completed',
      });
      transaction.update(userRef, {'activeRideSession': FieldValue.delete()});
      return true;
    });
  }

  Future<void> _updateRideSession() async {
    final uid = _uid;
    final position = _commuterPosition;
    if (uid == null || position == null) return;
    if (_updatingSession) {
      _updateRequested = true;
      return;
    }

    _updatingSession = true;
    try {
      if (!_activeSessionLoaded) {
        await _loadActiveRideSession(uid);
        if (!_activeSessionLoaded) return;
      }

      final now = DateTime.now();
      final activeSession = _activeSession;
      if (activeSession == null) {
        _clearExitCandidate();
        final nearbyBus = _nearestBusWithin(position, _entryRadiusMeters);
        if (nearbyBus == null) {
          _clearEntryCandidate();
          _setRideStatus();
          return;
        }

        if (_candidateDriverId != nearbyBus.driverId ||
            _candidateSince == null) {
          _clearEntryCandidate();
          _candidateDriverId = nearbyBus.driverId;
          _candidateSince = now;
          _scheduleEntryCheck(_entryDwell);
        }

        final elapsed = now.difference(_candidateSince!);
        if (elapsed < _entryDwell) {
          if (_entryTimer == null) {
            _scheduleEntryCheck(_entryDwell - elapsed);
          }
          _setRideStatus(pendingPlate: nearbyBus.plateNumber);
          return;
        }

        _entryTimer?.cancel();
        _entryTimer = null;
        final started = await _beginRideSession(uid, nearbyBus);
        _clearEntryCandidate();
        if (!started) {
          await _loadActiveRideSession(uid);
          return;
        }
        _setRideNotification(
          id: 'started:${_activeSession!['rideId']}',
          title: 'Ride started',
          message: 'Ride detected on PUV ${nearbyBus.plateNumber}.',
          nearbyPlate: nearbyBus.plateNumber,
        );
        return;
      }

      _clearEntryCandidate();
      final activePlate = activeSession['toPlate'];
      if (_busTracking.serverConnectionStatus.value !=
          'Connected to live PUV service') {
        _clearExitCandidate();
        _setRideStatus(nearbyPlate: activePlate is String ? activePlate : null);
        return;
      }

      ActiveBus? activeBus;
      if (activePlate is String) {
        for (final bus in _trackedBuses) {
          if (bus.isActive && bus.plateNumber == activePlate) {
            activeBus = bus;
            break;
          }
        }
      }

      final isWithinExitRadius =
          activeBus != null &&
          _distance.as(LengthUnit.Meter, position, activeBus.position) <=
              _exitRadiusMeters;
      if (isWithinExitRadius) {
        _clearExitCandidate();
        _setRideStatus(nearbyPlate: activePlate as String?);
        return;
      }

      _outsideSince ??= now;
      final outsideDuration = now.difference(_outsideSince!);
      if (outsideDuration < _exitDwell) {
        if (_exitTimer == null) {
          _scheduleExitCheck(_exitDwell - outsideDuration);
        }
        _setRideStatus(nearbyPlate: activePlate as String?);
        return;
      }

      _exitTimer?.cancel();
      _exitTimer = null;
      final completed = await _completeRideSession(uid, activeSession);
      if (!completed) {
        await _loadActiveRideSession(uid);
        return;
      }

      final completedPlate = activePlate is String ? activePlate : 'PUV';
      final completedRideId =
          activeSession['rideId']?.toString() ??
          now.microsecondsSinceEpoch.toString();
      _activeSession = null;
      _activeSessionLoaded = true;
      _outsideSince = null;
      _setRideNotification(
        id: 'completed:$completedRideId',
        title: 'Ride completed',
        message: 'Your ride on PUV $completedPlate was added to Recent Rides.',
      );
      _updateRequested = true;
    } catch (error) {
      _setMessage('Unable to update ride history: $error');
    } finally {
      _updatingSession = false;
      if (_updateRequested) {
        _updateRequested = false;
        unawaited(_updateRideSession());
      }
    }
  }
}

class RidesScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final Future<void> Function()? onShowMap;

  const RidesScreen({super.key, this.onMenuPressed, this.onShowMap});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  static String? _lastShownNotificationId;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _tracker = _CommuterRideTracker.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  List<Map<String, dynamic>> _recordsFrom(dynamic value) {
    if (value is! Iterable) return [];
    return value
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tracker.viewState.addListener(_onTrackerStateChanged);
    unawaited(_tracker.ensureStarted(_uid));
  }

  @override
  void dispose() {
    _tracker.viewState.removeListener(_onTrackerStateChanged);
    super.dispose();
  }

  void _onTrackerStateChanged() {
    if (!mounted) return;
    final trackerState = _tracker.viewState.value;
    final notificationId = trackerState.notificationId;
    final notificationMessage = trackerState.notificationMessage;
    if (notificationId != null &&
        notificationId != _lastShownNotificationId &&
        notificationMessage != null) {
      _lastShownNotificationId = notificationId;
      PopupNotif(
        message: notificationMessage,
        title: trackerState.notificationTitle,
        type: NotifType.info,
      ).show(context);
    }
    setState(() {});
  }

  Future<void> _checkNearbyPuv() async {
    final foundPuv = await _tracker.refreshLocation();
    if (!mounted) return;
    if (!foundPuv) {
      if (_tracker.viewState.value.message == null) {
        _showMessage('No active PUV detected nearby.', 'Info', NotifType.info);
      }
      return;
    }

    final onShowMap = widget.onShowMap;
    if (onShowMap != null) {
      await onShowMap();
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> _toggleFavorite(
    String uid,
    Map<String, dynamic> ride,
    bool isFavorite,
  ) async {
    final userRef = _userRef(uid);
    final rideId = ride['id'] as String?;
    if (rideId == null || rideId.isEmpty) return;

    try {
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw StateError('Your user profile could not be found.');
        }
        final savedRides = _recordsFrom(userSnapshot.data()?['savedRides']);
        savedRides.removeWhere((saved) => saved['rideId'] == rideId);
        if (!isFavorite) {
          savedRides.add({
            'rideId': rideId,
            'driverId': ride['driverId'],
            'toPlate': ride['toPlate'],
            'routeId': ride['routeId'],
            'startedAt': ride['startedAt'],
            'endedAt': ride['endedAt'],
            'durationSeconds': ride['durationSeconds'],
            'status': ride['status'],
          });
        }
        transaction.update(userRef, {'savedRides': savedRides});
      });
      _showMessage(
        isFavorite ? 'Ride removed from favorites.' : 'Ride saved.',
        'Info',
        NotifType.info,
      );
    } catch (error) {
      _showMessage(
        'Unable to update favorites: $error',
        'Error',
        NotifType.error,
      );
    }
  }

  Future<void> _deleteRide(String uid, String rideId) async {
    final rideRef = _db.collection('rides').doc(rideId);
    try {
      await _db.runTransaction((transaction) async {
        final rideSnapshot = await transaction.get(rideRef);
        if (!rideSnapshot.exists) return;
        if (rideSnapshot.data()?['commuterUid'] != uid) {
          throw StateError('You can only delete your own rides.');
        }
        transaction.delete(rideRef);
      });
      _showMessage('Ride deleted.', 'Info', NotifType.info);
    } catch (error) {
      _showMessage('Unable to delete ride: $error', 'Error', NotifType.error);
    }
  }

  Future<void> _confirmDeleteRide(String uid, String rideId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: 'Delete ride?',
        content: 'This recent ride will be permanently removed.',
        confirmText: 'Delete',
      ),
    );
    if (shouldDelete == true) await _deleteRide(uid, rideId);
  }

  Future<void> _showRideDetails(
    BuildContext context,
    Map<String, dynamic> ride,
  ) async {
    final startedAt = _formatDate(ride['startedAt']);
    final endedAt = _formatDate(ride['endedAt']);
    final durationSeconds = ride['durationSeconds'] as int? ?? 0;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ride Details'),
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
            Text('Duration: ${minutes}m ${seconds}s'),
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
    PopupNotif(message: message, title: title, type: type).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _uid;

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'Recent Rides',
        onMenuPressed: widget.onMenuPressed,
      ),
      floatingActionButton: uid == null
          ? null
          : FloatingButton(
              heroTag: 'rides-check-nearby-puv',
              onPressed: _checkNearbyPuv,
              icon: Icons.my_location,
              label: 'Check Nearby PUV',
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
                  'Recent Rides',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_tracker.viewState.value.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _tracker.viewState.value.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ] else if (_tracker.viewState.value.nearbyPlate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ride in progress near PUV '
                    '${_tracker.viewState.value.nearbyPlate}',
                  ),
                ] else if (_tracker.viewState.value.pendingPlate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Stay near PUV ${_tracker.viewState.value.pendingPlate} '
                    'for 30 seconds to register the ride.',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: uid == null
                ? const Center(
                    child: Text('Sign in to view your recent rides.'),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _userRef(uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Error loading rides: ${snapshot.error}',
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Loader.circular();
                      }

                      final favoriteIds = _recordsFrom(
                        snapshot.data?.data()?['savedRides'],
                      ).map((ride) => ride['rideId']).toSet();
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _db
                            .collection('rides')
                            .where('commuterUid', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, ridesSnapshot) {
                          if (ridesSnapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Error loading rides: ${ridesSnapshot.error}',
                                ),
                              ),
                            );
                          }
                          if (ridesSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Loader.circular();
                          }

                          final rides =
                              ridesSnapshot.data?.docs
                                  .map(
                                    (document) => {
                                      'id': document.id,
                                      ...document.data(),
                                    },
                                  )
                                  .toList() ??
                              <Map<String, dynamic>>[];
                          rides.sort((first, second) {
                            final firstTime = first['endedAt'];
                            final secondTime = second['endedAt'];
                            final firstMillis = firstTime is Timestamp
                                ? firstTime.millisecondsSinceEpoch
                                : 0;
                            final secondMillis = secondTime is Timestamp
                                ? secondTime.millisecondsSinceEpoch
                                : 0;
                            return secondMillis.compareTo(firstMillis);
                          });

                          if (rides.isEmpty) {
                            return const Center(
                              child: Text(
                                'No recent rides yet. Stay near an active PUV, then leave its detection area.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                            itemCount: rides.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final ride = rides[index];
                              final rideId = ride['id'] as String? ?? '';
                              final isFavorite = favoriteIds.contains(rideId);
                              final route =
                                  ride['routeId'] as String? ?? 'Unknown route';
                              final plate = ride['toPlate'] as String? ?? 'N/A';

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              route,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: isFavorite
                                                ? 'Unfavorite ride'
                                                : 'Favorite ride',
                                            onPressed: () => _toggleFavorite(
                                              uid,
                                              ride,
                                              isFavorite,
                                            ),
                                            icon: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete ride',
                                            onPressed: () =>
                                                _confirmDeleteRide(uid, rideId),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text('Vehicle: $plate'),
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
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
