import 'package:geolocator/geolocator.dart';

enum LocationFailure { servicesOff, denied, deniedForever, unavailable }

class LocationFix {
  const LocationFix({required this.lat, required this.lng, required this.accuracyMeters});
  final double lat;
  final double lng;
  final double accuracyMeters;

  /// <=15 m Good, <=50 m Fair, otherwise Poor (the student should pick a start manually).
  String get accuracyLabel => accuracyMeters <= 15 ? 'Good' : (accuracyMeters <= 50 ? 'Fair' : 'Poor');
}

class LocationOutcome {
  const LocationOutcome.fix(LocationFix this.fix) : failure = null;
  const LocationOutcome.failed(LocationFailure this.failure) : fix = null;
  final LocationFix? fix;
  final LocationFailure? failure;
}

abstract class LocationService {
  Future<LocationOutcome> current();
}

/// Device GPS via the platform location permission. Every failure is reported (never thrown) so the
/// UI can fall back to choosing a starting building or room by hand.
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationOutcome> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome.failed(LocationFailure.servicesOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return const LocationOutcome.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationOutcome.failed(LocationFailure.denied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return LocationOutcome.fix(LocationFix(lat: pos.latitude, lng: pos.longitude, accuracyMeters: pos.accuracy));
    } catch (_) {
      return const LocationOutcome.failed(LocationFailure.unavailable);
    }
  }
}

String describeFailure(LocationFailure f) => switch (f) {
      LocationFailure.servicesOff => 'Location services are turned off.',
      LocationFailure.denied => 'Location permission was not granted.',
      LocationFailure.deniedForever => 'Location permission is blocked. Enable it in Settings, or choose a start below.',
      LocationFailure.unavailable => 'Your location could not be determined.',
    };
