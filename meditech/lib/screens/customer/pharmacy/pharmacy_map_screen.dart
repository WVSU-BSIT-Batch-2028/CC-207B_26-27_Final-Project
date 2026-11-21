import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'pharmacy_details_screen.dart';

// Guest/customer map of approved pharmacy branches (Main Flow "View maps")
class PharmacyMapScreen extends ConsumerStatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  ConsumerState<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends ConsumerState<PharmacyMapScreen> {
  static const _iloilo = LatLng(10.7202, 122.5621);
  final _map = MapController();
  PharmacyDetail? _selected;

  void _openDetails(PharmacyDetail pharmacy) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsScreen(
          branchId: pharmacy.branchId,
          initialTitle: pharmacy.pharmacyName,
        ),
      ),
    );
  }

  void _focusPharmacy(PharmacyDetail pharmacy) {
    setState(() => _selected = pharmacy);
    _map.move(LatLng(pharmacy.latitude, pharmacy.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(publicBranchesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pharmacy map'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: AsyncView<List<PharmacyDetail>>(
        value: branchesAsync,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No approved pharmacies are listed yet.',
        onRetry: () => ref.invalidate(publicBranchesProvider),
        builder: (branches) {
          final markers = branches
              .where((b) => b.latitude != 0 || b.longitude != 0)
              .map(
                (branch) => Marker(
                  point: LatLng(branch.latitude, branch.longitude),
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _focusPharmacy(branch),
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: _selected?.branchId == branch.branchId
                          ? AppColors.primary
                          : AppColors.danger,
                    ),
                  ),
                ),
              )
              .toList();

          final center = markers.isEmpty
              ? _iloilo
              : LatLng(branches.first.latitude, branches.first.longitude);

          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all &
                        ~InteractiveFlag.scrollWheelZoom &
                        ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ph.meditech',
                  ),
                  MarkerLayer(markers: markers),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              if (_selected != null)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      onTap: () => _openDetails(_selected!),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selected!.pharmacyName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selected!.branchName,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selected!.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
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
