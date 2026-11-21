import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'medicine_providers.dart';

// A readable place name for the signed-in device, when location is allowed
class CustomerPlace {
  const CustomerPlace({this.label, this.latitude, this.longitude});

  final String? label;
  final double? latitude;
  final double? longitude;
}

// Asks for the device location once and turns it into a short address
final customerLocationProvider = FutureProvider<CustomerPlace>((ref) async {
  final place = await _loadCustomerPlace();
  final latitude = place.latitude;
  final longitude = place.longitude;
  if (latitude != null && longitude != null) {
    ref
        .read(medicineSearchFilterProvider.notifier)
        .setCoordinates(latitude, longitude);
  }
  return place;
});

Future<CustomerPlace> _loadCustomerPlace() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return const CustomerPlace();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const CustomerPlace();
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final label = await _reverseLabel(position.latitude, position.longitude);
    return CustomerPlace(
      label: label,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (_) {
    return const CustomerPlace();
  }
}

Future<String?> _reverseLabel(double latitude, double longitude) async {
  try {
    final uri = Uri.https(
      'api.bigdatacloud.net',
      '/data/reverse-geocode-client',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'localityLanguage': 'en',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return _placeLabel(json);
  } catch (_) {
    return null;
  }
}

String? _placeLabel(Map<String, dynamic> json) {
  final parts = <String>[];
  void add(Object? value) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return;
    final lower = text.toLowerCase();
    if (parts.any((part) => part.toLowerCase() == lower)) return;
    parts.add(text);
  }

  final info = json['localityInfo'];
  if (info is Map) {
    final informative = info['informative'];
    if (informative is List) {
      for (final item in informative) {
        if (item is Map && item['description'] == 'street') {
          add(item['name']);
          break;
        }
      }
    }
  }
  add(json['locality']);
  add(json['city']);
  if (parts.isEmpty) add(json['principalSubdivision']);
  if (parts.isEmpty) return null;
  return parts.take(3).join(', ');
}
