import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/osm_listing.dart';

class OsmListingService {
  OsmListingService({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<List<OsmListing>> fetchShownListings() async {
    final rows = await _db
        .from('osm_listings')
        .select(
          'id, osm_id, name, address, latitude, longitude, last_edited_there, status, synced_at',
        )
        .eq('status', 'shown')
        .order('name', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) => OsmListing.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<OsmListing?> fetchListingById(String id) async {
    final row = await _db
        .from('osm_listings')
        .select(
          'id, osm_id, name, address, latitude, longitude, last_edited_there, status, synced_at',
        )
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return OsmListing.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<OsmListing>> findNearbyListings({
    required double latitude,
    required double longitude,
    int radiusMeters = 100,
  }) async {
    final rows = await _db.rpc(
      'find_nearby_osm_listings',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_meters': radiusMeters,
      },
    );

    return (rows as List<dynamic>)
        .map(
          (row) => OsmListing.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<OsmListing>> fetchAllForAdmin() async {
    final rows = await _db
        .from('osm_listings')
        .select(
          'id, osm_id, name, address, latitude, longitude, last_edited_there, '
          'status, hidden_reason, replaced_by_branch_id, synced_at, '
          'branches:replaced_by_branch_id(pharmacy_name, branch_name)',
        )
        .order('name', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) => OsmListing.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> hideListing({
    required String listingId,
    required String reason,
  }) async {
    await _db.rpc(
      'admin_hide_osm_listing',
      params: {'p_listing_id': listingId, 'p_reason': reason.trim()},
    );
  }

  Future<void> showListingAgain({required String listingId}) async {
    await _db.rpc(
      'admin_show_osm_listing',
      params: {'p_listing_id': listingId},
    );
  }

  Future<int> syncFromOpenStreetMap() async {
    const query = '''
    [out:json][timeout:25];
    (
      node["amenity"="pharmacy"]["name"](10.67,122.48,10.78,122.62);
      way["amenity"="pharmacy"]["name"](10.67,122.48,10.78,122.62);
    );
    out center meta qt;
    ''';

    const mirrors = [
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass-api.de/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    List<dynamic>? elements;
    for (final mirror in mirrors) {
      try {
        final response = await http
            .post(
              Uri.parse(mirror),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final list = decoded['elements'];
          if (list is List) {
            elements = list;
            break;
          }
        }
      } catch (_) {
        // Try next mirror
      }
    }

    if (elements == null) {
      throw Exception(
        'OpenStreetMap is slow or busy. Wait a minute and tap Sync OSM again.',
      );
    }

    try {
      final res = await _db.functions.invoke(
        'osm-sync',
        body: {'elements': elements},
      );
      final data = res.data;
      if (data is Map && data['synced'] is num) {
        return (data['synced'] as num).toInt();
      }
      throw Exception('OpenStreetMap sync returned an invalid response.');
    } on FunctionException catch (error) {
      final data = error.details ?? error.toString();
      if (data is Map) {
        final message = data['error'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      if (error.status == 502 || error.status == 504) {
        throw Exception(
          'OpenStreetMap is slow or busy (HTTP ${error.status}). '
          'Wait a minute and tap Sync OSM again.',
        );
      }
      throw Exception('Could not sync OpenStreetMap listings.');
    }
  }
}
