import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/nearby_osm_listings_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Store location: buttons, an inline map with a pin, and coordinate boxes
class LocationSection extends StatefulWidget {
  const LocationSection({super.key, required this.draft, this.serverError});

  final RegistrationDraft draft;
  final String? serverError;

  // Tests turn this off, since the map needs the internet
  static bool showMap = true;

  @override
  State<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<LocationSection> {
  static const _iloilo = LatLng(10.7202, 122.5621); // where the map starts
  final _map = MapController();
  bool _locating = false;
  bool _showBubble = true;

  RegistrationDraft get d => widget.draft;

  // The pin's spot, if the boxes hold a real location
  LatLng? get _pin {
    final lat = double.tryParse(d.latitude.text);
    final lng = double.tryParse(d.longitude.text);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  // Put the pin on a spot and fill in the boxes
  void _setPin(LatLng spot, FormFieldState<bool> field, {bool moveMap = true}) {
    setState(() {
      d.latitude.text = spot.latitude.toStringAsFixed(6);
      d.longitude.text = spot.longitude.toStringAsFixed(6);
      d.claimedOsmListingId = null;
      _showBubble = true;
    });
    if (moveMap) _map.move(spot, max(_map.camera.zoom, 16));
    field.didChange(true);
  }

  // Use the device's location
  Future<void> _useCurrentLocation(FormFieldState<bool> field) async {
    void tell(String message) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));

    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        tell('Turn on location, or tap the map to drop a pin.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        tell(
          'Location permission was denied. Tap the map to drop a pin instead.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _setPin(LatLng(position.latitude, position.longitude), field);
    } catch (_) {
      tell('Could not get your location. Tap the map to drop a pin instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Drop the pin in the middle of what the map is showing
  void _dropPin(FormFieldState<bool> field) =>
      _setPin(_map.camera.center, field, moveMap: false);

  // Zoom in or out with the buttons
  void _zoom(double by) =>
      _map.move(_map.camera.center, (_map.camera.zoom + by).clamp(3.0, 19.0));

  // Typing in the boxes moves the pin
  void _typed(FormFieldState<bool> field) {
    final spot = _pin;
    setState(() {
      d.claimedOsmListingId = null;
      _showBubble = true;
    });
    if (spot != null) _map.move(spot, _map.camera.zoom);
    field.didChange(spot != null);
  }

  // Coordinates must be real numbers in range
  String? _coordinate(String? value, double limit) {
    final n = double.tryParse(value ?? '');
    if (n == null) return 'Set the store location.';
    return (n < -limit || n > limit) ? 'Not a valid location.' : null;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      validator: (_) => d.hasLocation ? null : 'Set the store location.',
      builder: (field) {
        final pin = _pin;
        final error = field.errorText ?? widget.serverError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Row(
              children: [
                Icon(Icons.place, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Store location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              "Do this while you're at the store for the most accurate pin. "
              'Patients get directions to this exact spot.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),

            // Two ways to set the pin
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _locating
                      ? null
                      : () => _useCurrentLocation(field),
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Use my current location'),
                ),
                const Text('or', style: TextStyle(color: AppColors.textMuted)),
                OutlinedButton.icon(
                  onPressed: () => _dropPin(field),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Drop a pin on the map'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // The map
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  children: [
                    if (LocationSection.showMap)
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: pin ?? _iloilo,
                          initialZoom: pin != null ? 17 : 14,
                          // Tap anywhere to move the pin there
                          onTap: (_, spot) =>
                              _setPin(spot, field, moveMap: false),
                          // Page scrolling with the mouse wheel shouldn't zoom the map
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom &
                                ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'ph.meditech',
                          ),
                          // Soft green circle around the pin
                          if (pin != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: pin,
                                  radius: 28,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderColor: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderStrokeWidth: 1,
                                ),
                              ],
                            ),
                          // The pin, with its tip on the exact spot
                          if (pin != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pin,
                                  width: 220,
                                  height: 120,
                                  alignment: Alignment.topCenter,
                                  child: _PinWithBubble(
                                    spot: pin,
                                    showBubble: _showBubble,
                                    onCloseBubble: () =>
                                        setState(() => _showBubble = false),
                                  ),
                                ),
                              ],
                            ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      // Plain box shown in tests instead of the map
                      Container(color: AppColors.neutralLight),

                    // Hint before a pin is set
                    if (pin == null)
                      const Positioned(
                        top: AppSpacing.md,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Text('Tap the map to drop a pin'),
                            ),
                          ),
                        ),
                      ),

                    // Zoom and recenter buttons
                    Positioned(
                      right: AppSpacing.md,
                      bottom: AppSpacing.xl,
                      child: Column(
                        children: [
                          _MapButton(
                            icon: Icons.add,
                            tooltip: 'Zoom in',
                            onTap: () => _zoom(1),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _MapButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom out',
                            onTap: () => _zoom(-1),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _MapButton(
                            icon: Icons.gps_fixed,
                            tooltip: 'Go to my location',
                            onTap: () => _useCurrentLocation(field),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Success message once the pin is set
            if (pin != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Location set successfully! ',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: 'You can adjust the pin anytime.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Coordinate boxes; typing moves the pin
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Latitude',
                    hint: '10.720200',
                    controller: d.latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) => _typed(field),
                    validator: (v) => _coordinate(v, 90),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Longitude',
                    hint: '122.562100',
                    controller: d.longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) => _typed(field),
                    validator: (v) => _coordinate(v, 180),
                  ),
                ),
              ],
            ),

            // Nearby OpenStreetMap duplicate check once the pin is set
            if (pin != null) ...[
              const SizedBox(height: AppSpacing.md),
              NearbyOsmListingsCard(
                latitude: pin.latitude,
                longitude: pin.longitude,
                selectedListingId: d.claimedOsmListingId,
                onSelectListing: (listing) {
                  setState(() {
                    d.claimedOsmListingId = listing?.id;
                    if (listing != null && d.pharmacyName.text.trim().isEmpty) {
                      d.pharmacyName.text = listing.name;
                    }
                    if (listing != null &&
                        d.address.text.trim().isEmpty &&
                        listing.address.isNotEmpty) {
                      d.address.text = listing.address;
                    }
                  });
                },
              ),
            ],

            if (error != null && pin == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

// The pin, with a "Selected Location" bubble above it
class _PinWithBubble extends StatelessWidget {
  const _PinWithBubble({
    required this.spot,
    required this.showBubble,
    required this.onCloseBubble,
  });

  final LatLng spot;
  final bool showBubble;
  final VoidCallback onCloseBubble;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showBubble)
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selected location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Hide',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onCloseBubble,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        const Icon(Icons.location_pin, size: 40, color: AppColors.primary),
      ],
    );
  }
}

// A small white square button on the map
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onTap),
    );
  }
}
