import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'congestion_predictor_service.dart';

class ActiveBus {
  const ActiveBus({
    required this.driverId,
    required this.plateNumber,
    required this.routeName,
    required this.position,
    required this.speedKmh,
    required this.isActive,
    required this.startedAt,
    this.isFull = false,
  });

  final String driverId;
  final String plateNumber;
  final String routeName;
  final LatLng position;
  final double speedKmh;
  final bool isActive;
  final DateTime startedAt;
  final bool isFull;

  ActiveBus copyWith({
    LatLng? position,
    double? speedKmh,
    bool? isActive,
    bool? isFull,
  }) {
    return ActiveBus(
      driverId: driverId,
      plateNumber: plateNumber,
      routeName: routeName,
      position: position ?? this.position,
      speedKmh: speedKmh ?? this.speedKmh,
      isActive: isActive ?? this.isActive,
      startedAt: startedAt,
      isFull: isFull ?? this.isFull,
    );
  }
}

class DriverTrip {
  const DriverTrip({
    required this.driverId,
    required this.plateNumber,
    required this.routeName,
    required this.startedAt,
    required this.endedAt,
    this.tripId,
  });

  final String driverId;
  final String plateNumber;
  final String routeName;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? tripId;

  String get resolvedId =>
      tripId ??
      '${Uri.encodeComponent(driverId)}_${startedAt.microsecondsSinceEpoch}';

  Duration get duration => endedAt.difference(startedAt);
}

class DriverTripSyncException implements Exception {
  const DriverTripSyncException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'The ride ended, but driver analytics could not be synced: $cause';
}

class LocalBusTrackingService {
  LocalBusTrackingService._();

  static final LocalBusTrackingService instance = LocalBusTrackingService._();
  static const String _socketUrl = 'https://lookout-p8fw.onrender.com';

  final ValueNotifier<List<ActiveBus>> activeBuses =
      ValueNotifier<List<ActiveBus>>(<ActiveBus>[]);
  final ValueNotifier<List<DriverTrip>> completedTrips =
      ValueNotifier<List<DriverTrip>>(<DriverTrip>[]);
  final ValueNotifier<String> serverConnectionStatus = ValueNotifier<String>(
    'Not connected',
  );

  socket_io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _simulationTimer;
  final Set<String> _localDriverIds = <String>{};
  final Set<String> _driversWithGps = <String>{};
  final Map<String, String> _remoteSocketIdsByPlate = <String, String>{};
  final List<LatLng> _waypoints = const [
    LatLng(10.7495, 122.5432),
    LatLng(10.7258, 122.5572),
    LatLng(10.7138, 122.5635),
    LatLng(10.7030, 122.5665),
  ];

  Future<bool> startRide({
    required String driverId,
    required String plateNumber,
    required String routeName,
  }) async {
    await _stopRide(driverId, recordTrip: false);
    _localDriverIds.add(driverId);
    _driversWithGps.remove(driverId);

    final initialBus = ActiveBus(
      driverId: driverId,
      plateNumber: plateNumber,
      routeName: routeName,
      position: _waypoints.first,
      speedKmh: 20,
      isActive: true,
      startedAt: DateTime.now(),
    );
    final buses = List<ActiveBus>.from(activeBuses.value)
      ..removeWhere((bus) => bus.driverId == driverId)
      ..add(initialBus);
    activeBuses.value = buses;
    connectToServer();
    _emitLocation(initialBus);

    final canTrack = await _startPositionStream(
      driverId: driverId,
      plateNumber: plateNumber,
      routeName: routeName,
    );
    if (!canTrack) {
      _startWaypointTimer(
        driverId: driverId,
        plateNumber: plateNumber,
        routeName: routeName,
      );
    }
    return canTrack;
  }

  void setDriverAvailability({required String driverId, required bool isFull}) {
    final buses = List<ActiveBus>.from(activeBuses.value);
    final index = buses.indexWhere(
      (bus) => bus.driverId == driverId && bus.isActive,
    );
    if (index == -1 || buses[index].isFull == isFull) return;

    final bus = buses[index].copyWith(isFull: isFull);
    buses[index] = bus;
    activeBuses.value = buses;

    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('setAvailability', {
        'vehicleId': bus.plateNumber,
        'full': isFull,
      });
    }
  }

  Future<bool> _startPositionStream({
    required String driverId,
    required String plateNumber,
    required String routeName,
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            _simulationTimer?.cancel();
            _simulationTimer = null;
            _driversWithGps.add(driverId);
            _updateBus(
              driverId: driverId,
              plateNumber: plateNumber,
              routeName: routeName,
              position: LatLng(position.latitude, position.longitude),
              speedKmh: position.speed > 0 ? position.speed * 3.6 : 20,
            );
          },
          onError: (_) {
            _driversWithGps.remove(driverId);
            _startWaypointTimer(
              driverId: driverId,
              plateNumber: plateNumber,
              routeName: routeName,
            );
          },
        );
    return true;
  }

  void _startWaypointTimer({
    required String driverId,
    required String plateNumber,
    required String routeName,
  }) {
    _simulationTimer?.cancel();
    var waypointIndex = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      waypointIndex = (waypointIndex + 1) % _waypoints.length;
      _updateBus(
        driverId: driverId,
        plateNumber: plateNumber,
        routeName: routeName,
        position: _waypoints[waypointIndex],
        speedKmh: 20,
      );
    });
  }

  void _updateBus({
    required String driverId,
    required String plateNumber,
    required String routeName,
    required LatLng position,
    required double speedKmh,
  }) async {
    final buses = activeBuses.value.map((bus) {
      if (bus.driverId != driverId) return bus;
      return bus.copyWith(
        position: position,
        speedKmh: speedKmh,
        isActive: true,
      );
    }).toList();
    if (!buses.any((bus) => bus.driverId == driverId)) {
      buses.add(
        ActiveBus(
          driverId: driverId,
          plateNumber: plateNumber,
          routeName: routeName,
          position: position,
          speedKmh: speedKmh,
          isActive: true,
          startedAt: DateTime.now(),
        ),
      );
    }
    activeBuses.value = buses;
    if (_driversWithGps.contains(driverId)) {
      final updatedBus = buses.firstWhere((bus) => bus.driverId == driverId);
      _emitLocation(updatedBus);
    }
  }

  void connectToServer() {
    if (_socket != null) return;

    serverConnectionStatus.value = 'Connecting to live PUV service';
    final socket = socket_io.io(_socketUrl, <String, dynamic>{
      if (!kIsWeb) 'transports': <String>['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'timeout': 20000,
    });
    _socket = socket;

    socket.onConnect((_) {
      serverConnectionStatus.value = 'Connected to live PUV service';
      for (final bus in activeBuses.value) {
        _emitLocation(bus);
      }
    });
    socket.onDisconnect((_) {
      serverConnectionStatus.value = 'Reconnecting to live PUV service';
    });
    socket.onConnectError((error) {
      serverConnectionStatus.value =
          'Unable to connect to live PUV service: $error';
    });
    socket.on('activeDrivers', _handleActiveDrivers);
    socket.on('driverMoved', _handleDriverMoved);
    socket.on('driverDisconnected', _handleDriverDisconnected);
    socket.on('invalidPayload', (payload) {
      final data = _socketMap(payload);
      final reason = data?['reason']?.toString() ?? 'Invalid location update';
      serverConnectionStatus.value = 'Live PUV update rejected: $reason';
    });
    socket.connect();
  }

  void _emitLocation(ActiveBus bus) {
    final socket = _socket;
    if (socket == null ||
        !socket.connected ||
        !_driversWithGps.contains(bus.driverId)) {
      return;
    }
    socket.emit('updateLocation', <String, dynamic>{
      'vehicleId': bus.plateNumber,
      'routeId': bus.routeName,
      'lat': bus.position.latitude,
      'lng': bus.position.longitude,
      'speed': bus.speedKmh,
      'heading': 0,
      'full': bus.isFull,
    });
  }

  void _handleActiveDrivers(dynamic payload) {
    if (payload is! List) return;
    activeBuses.value = activeBuses.value
        .where((bus) => _localDriverIds.contains(bus.driverId))
        .toList();
    _remoteSocketIdsByPlate.clear();
    for (final record in payload) {
      _upsertRemoteDriver(record);
    }
  }

  void _handleDriverMoved(dynamic payload) {
    _upsertRemoteDriver(payload);
  }

  void _upsertRemoteDriver(dynamic payload) {
    final data = _socketMap(payload);
    if (data == null) return;
    final vehicleId = data['vehicleId'];
    final socketId = data['socketId'];
    final latitude = data['lat'];
    final longitude = data['lng'];
    if (vehicleId is! String ||
        vehicleId.isEmpty ||
        socketId is! String ||
        latitude is! num ||
        longitude is! num) {
      return;
    }

    if (activeBuses.value.any(
      (bus) =>
          _localDriverIds.contains(bus.driverId) &&
          bus.plateNumber == vehicleId,
    )) {
      return;
    }

    DateTime? startedAt;
    for (final bus in activeBuses.value) {
      if (bus.plateNumber == vehicleId) {
        startedAt = bus.startedAt;
        break;
      }
    }
    final speed = data['speed'];
    final routeId = data['routeId'];
    final remoteBus = ActiveBus(
      driverId: socketId,
      plateNumber: vehicleId,
      routeName: routeId is String ? routeId : 'Unknown route',
      position: LatLng(latitude.toDouble(), longitude.toDouble()),
      speedKmh: speed is num ? speed.toDouble() : 0,
      isActive: true,
      startedAt: startedAt ?? DateTime.now(),
      isFull: data['full'] == true,
    );
    _remoteSocketIdsByPlate[vehicleId] = socketId;
    activeBuses.value = [
      ...activeBuses.value.where(
        (bus) => bus.driverId != socketId && bus.plateNumber != vehicleId,
      ),
      remoteBus,
    ];
  }

  void _handleDriverDisconnected(dynamic payload) {
    final data = _socketMap(payload);
    final vehicleId = data?['vehicleId'];
    if (vehicleId is! String || vehicleId.isEmpty) return;
    final socketId = _remoteSocketIdsByPlate.remove(vehicleId);
    if (_localDriverIds.any(
      (driverId) => activeBuses.value.any(
        (bus) => bus.driverId == driverId && bus.plateNumber == vehicleId,
      ),
    )) {
      return;
    }
    activeBuses.value = activeBuses.value
        .where(
          (bus) =>
              bus.plateNumber != vehicleId ||
              (socketId != null && bus.driverId != socketId),
        )
        .toList();
  }

  Map<String, dynamic>? _socketMap(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  Future<void> stopRide(String driverId) {
    return _stopRide(driverId, recordTrip: true);
  }

  Future<void> deleteTrip(DriverTrip trip) async {
    final targetId = trip.resolvedId;
    completedTrips.value = completedTrips.value
        .where((item) => item.resolvedId != targetId)
        .toList();

    await FirebaseFirestore.instance
        .collection('driver_trips')
        .doc(targetId)
        .delete();
  }

  Future<void> _stopRide(String driverId, {required bool recordTrip}) async {
    ActiveBus? activeBus;
    for (final bus in activeBuses.value) {
      if (bus.driverId == driverId) {
        activeBus = bus;
        break;
      }
    }
    if (activeBus != null) {
      final socket = _socket;
      if (socket != null && socket.connected) {
        socket.emit('endTrip', <String, dynamic>{
          'vehicleId': activeBus.plateNumber,
        });
      }
    }
    final endedAt = DateTime.now();
    final completedTrip = recordTrip && activeBus != null
        ? DriverTrip(
            driverId: activeBus.driverId,
            plateNumber: activeBus.plateNumber,
            routeName: activeBus.routeName,
            startedAt: activeBus.startedAt,
            endedAt: endedAt,
          )
        : null;
    if (completedTrip != null) {
      completedTrips.value = [completedTrip, ...completedTrips.value];
    }

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _localDriverIds.remove(driverId);
    _driversWithGps.remove(driverId);
    activeBuses.value = activeBuses.value
        .where((bus) => bus.driverId != driverId)
        .toList();

    if (completedTrip != null) {
      final tripId =
          '${Uri.encodeComponent(completedTrip.driverId)}_'
          '${completedTrip.startedAt.microsecondsSinceEpoch}';
      try {
        await FirebaseFirestore.instance
            .collection('driver_trips')
            .doc(tripId)
            .set({
              'id': tripId,
              'driverUid': completedTrip.driverId,
              'plateNumber': completedTrip.plateNumber,
              'routeName': completedTrip.routeName,
              'startedAt': Timestamp.fromDate(completedTrip.startedAt),
              'endedAt': Timestamp.fromDate(completedTrip.endedAt),
              'durationSeconds': completedTrip.duration.inSeconds,
              'status': 'completed',
              'createdAt': FieldValue.serverTimestamp(),
            });
      } on FirebaseException catch (error) {
        throw DriverTripSyncException(error);
      }
    }
  }

  Future<double> calculateLocalEta({
    required LatLng commuterPosition,
    required ActiveBus bus,
  }) async {
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      commuterPosition,
      bus.position,
    );
    final travelDistanceKm = (distanceMeters * 1.28) / 1000;
    final speedKmh = bus.speedKmh > 0 ? bus.speedKmh : 20;
    var etaMins = (travelDistanceKm / speedKmh) * 60;

    final predictions = await CongestionPredictorService()
        .predictAllCorridors();
    for (final prediction in predictions) {
      final distanceToCorridor = const Distance().as(
        LengthUnit.Meter,
        bus.position,
        prediction.center,
      );
      if (distanceToCorridor <= 1500) {
        etaMins += prediction.extraDelayMins;
        break;
      }
    }
    return etaMins;
  }
}
