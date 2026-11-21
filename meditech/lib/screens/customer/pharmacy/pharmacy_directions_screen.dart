import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'pharmacy_details_screen.dart';

// Directions to one pharmacy: map, location chips, and a store card
class PharmacyDirectionsScreen extends ConsumerStatefulWidget {
  const PharmacyDirectionsScreen({
    super.key,
    required this.branchId,
    this.initialTitle,
  });

  final String branchId;
  final String? initialTitle;

  @override
  ConsumerState<PharmacyDirectionsScreen> createState() =>
      _PharmacyDirectionsScreenState();
}

class _PharmacyDirectionsScreenState
    extends ConsumerState<PharmacyDirectionsScreen> {
  static const _iloilo = LatLng(10.7202, 122.5621);
  final _map = MapController();
  bool _locating = false;
  String? _enteredLocation;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _tell('Turn on location to center the map on you.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _tell('Location permission was denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _map.move(LatLng(position.latitude, position.longitude), 15);
    } catch (_) {
      _tell('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _enterLocation() async {
    final controller = TextEditingController(text: _enteredLocation ?? '');
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Street, barangay, or city'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || entered == null) return;
    final label = entered.trim();
    if (label.isEmpty) return;
    setState(() => _enteredLocation = label);
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openPharmacy(PharmacyDetail pharmacy) {
    final name = Uri.encodeComponent(pharmacy.pharmacyName);
    if (GoRouter.maybeOf(context) != null) {
      context.push('/pharmacies/${pharmacy.branchId}?name=$name');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsScreen(
          branchId: pharmacy.branchId,
          initialTitle: pharmacy.pharmacyName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(pharmacyDetailProvider(widget.branchId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Directions'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: AsyncView<PharmacyDetail?>(
        value: detailAsync,
        isEmpty: (branch) => branch == null,
        emptyMessage: 'This pharmacy is currently unavailable.',
        onRetry: () => ref.invalidate(pharmacyDetailProvider(widget.branchId)),
        builder: (branch) {
          final pharmacy = branch!;
          final hasPin = pharmacy.latitude != 0 || pharmacy.longitude != 0;
          final point = hasPin
              ? LatLng(pharmacy.latitude, pharmacy.longitude)
              : _iloilo;

          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(initialCenter: point, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ph.meditech',
                  ),
                  if (hasPin)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.md,
                child: Row(
                  children: [
                    Expanded(
                      child: _LocationChip(
                        icon: Icons.my_location,
                        label: _locating ? 'Locating…' : 'Use current location',
                        onTap: _locating ? null : _useCurrentLocation,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _LocationChip(
                        icon: Icons.edit_location_alt_outlined,
                        label: _enteredLocation ?? 'Enter location',
                        onTap: _enterLocation,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    onTap: () => _openPharmacy(pharmacy),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              width: 56,
                              height: 56,
                              color: AppColors.primaryLight,
                              child: const Icon(
                                Icons.local_pharmacy,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pharmacy.pharmacyName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (pharmacy.branchName.isNotEmpty)
                                  Text(
                                    pharmacy.branchName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  pharmacy.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Registered on MediTech',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
