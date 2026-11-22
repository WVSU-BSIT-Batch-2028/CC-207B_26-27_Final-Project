import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/route_service.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Values passed into /directions so every Get directions button opens this screen
class DirectionsArgs {
  const DirectionsArgs({
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.destination,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final LatLng destination;
}

// Screen showing route, distance, and estimated travel time to a pharmacy
// Matches wireframes P-22 and P-23
class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({
    super.key,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.destination,
    this.routeService,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final LatLng destination;
  final RouteService? routeService;

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  late final RouteService _routeService;
  final _mapController = MapController();

  // Default starting point (Iloilo City center)
  static const _defaultOrigin = LatLng(10.7202, 122.5621);
  LatLng _origin = _defaultOrigin;
  String _originLabel = 'Iloilo City Center';

  bool _loading = false;
  bool _permissionDenied = false;
  RouteResult? _routeResult;

  @override
  void initState() {
    super.initState();
    _routeService = widget.routeService ?? RouteService();
    _initStartingLocation();
  }

  // Tries to get GPS coordinates, falls back to manual starting location if denied
  Future<void> _initStartingLocation() async {
    setState(() {
      _loading = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _permissionDenied = true;
          _originLabel = 'Iloilo City Center (GPS off)';
        });
        await _fetchRoute();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _permissionDenied = true;
          _originLabel = 'Iloilo City Center (Location denied)';
        });
        await _fetchRoute();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _originLabel = 'Current Location';
        _permissionDenied = false;
      });
    } catch (_) {
      setState(() {
        _permissionDenied = true;
        _originLabel = 'Iloilo City Center (Default)';
      });
    }

    await _fetchRoute();
  }

  // Requests route calculation between origin and pharmacy destination
  Future<void> _fetchRoute() async {
    setState(() => _loading = true);
    try {
      final result = await _routeService.getDirections(
        start: _origin,
        end: widget.destination,
      );

      if (mounted) {
        setState(() {
          _routeResult = result;
          _loading = false;
        });

        // Fit map bounds to show both origin and destination
        final points = [_origin, widget.destination, ...result.points];
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Allows patient to select a preset starting point when location is denied
  void _showChangeOriginDialog() {
    final presets = <String, LatLng>{
      'Iloilo City Hall': const LatLng(10.6929, 122.5694),
      'Jaro Plaza': const LatLng(10.7248, 122.5562),
      'SM City Iloilo': const LatLng(10.7145, 122.5492),
      'Central Philippine University': const LatLng(10.7303, 122.5487),
      'La Paz Plaza': const LatLng(10.7100, 122.5714),
    };

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Starting Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Choose where you are departing from:',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                ...presets.entries.map((entry) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _origin = entry.value;
                        _originLabel = entry.key;
                      });
                      _fetchRoute();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = _routeResult?.points.isNotEmpty == true
        ? _routeResult!.points
        : [_origin, widget.destination];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directions'),
        actions: [
          IconButton(
            tooltip: 'Recalculate route',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map view with route polyline and markers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _origin,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ph.meditech',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.0,
                    color: AppColors.primary,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Origin marker
                  Marker(
                    point: _origin,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.info,
                      size: 32,
                    ),
                  ),
                  // Destination marker
                  Marker(
                    point: widget.destination,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.danger,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Location permission banner when GPS is denied
          if (_permissionDenied)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Card(
                color: AppColors.warningLight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Location denied. Using manual starting point.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _showChangeOriginDialog,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top Starting Location Selector
          Positioned(
            top: _permissionDenied ? 60 : AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Card(
              elevation: 3,
              child: InkWell(
                onTap: _showChangeOriginDialog,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trip_origin,
                        size: 18,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _originLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_loading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Bottom card with pharmacy details, distance, and duration
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.local_pharmacy_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.pharmacyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              if (widget.branchName.isNotEmpty)
                                Text(
                                  widget.branchName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DISTANCE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _routeResult?.formattedDistance ?? '...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'ESTIMATED TIME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _routeResult?.formattedDuration ?? '...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
