import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/browse_store_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'pharmacy_details_screen.dart';

// Guest/customer map of approved pharmacy branches (Main Flow "View maps")
class PharmacyMapScreen extends ConsumerStatefulWidget {
  const PharmacyMapScreen({super.key, this.focusBranchId});

  final String? focusBranchId;

  @override
  ConsumerState<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends ConsumerState<PharmacyMapScreen> {
  static const _iloilo = LatLng(10.7202, 122.5621);
  final _map = MapController();
  String? _selectedId;
  bool _focused = false;

  void _openDetails(PharmacyDetail pharmacy) {
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

  void _focusPharmacy(PharmacyDetail pharmacy) {
    setState(() => _selectedId = pharmacy.branchId);
    if (pharmacy.latitude == 0 && pharmacy.longitude == 0) return;
    _map.move(LatLng(pharmacy.latitude, pharmacy.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(publicBranchesProvider);
    final hours = ref.watch(publicBranchHoursProvider).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AsyncView<List<PharmacyDetail>>(
        value: branchesAsync,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No approved pharmacies are listed yet.',
        onRetry: () => ref.invalidate(publicBranchesProvider),
        builder: (branches) {
          final focusId = widget.focusBranchId;
          if (!_focused && focusId != null) {
            for (final branch in branches) {
              if (branch.branchId == focusId) {
                _focused = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _focusPharmacy(branch);
                });
                break;
              }
            }
          }

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
                      size: _selectedId == branch.branchId ? 44 : 36,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
              .toList();

          final located = branches.where(
            (b) => b.latitude != 0 || b.longitude != 0,
          );
          final center = located.isEmpty
              ? _iloilo
              : LatLng(located.first.latitude, located.first.longitude);

          return SizedBox.expand(
            child: Stack(
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
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: AppSpacing.md,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (GoRouter.maybeOf(context)?.canPop() == true ||
                          Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                        return;
                      }
                      context.go('/home');
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.18,
                maxChildSize: 0.72,
                builder: (context, controller) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A1B2420),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                        const Text(
                          'Browse All Stores',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (var i = 0; i < branches.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.sm),
                          BrowseStoreCard(
                            name: branches[i].pharmacyName,
                            addressLine: branches[i].distanceKm == null
                                ? branches[i].address
                                : '${branches[i].address} • ${branches[i].distanceKm!.toStringAsFixed(1)} km',
                            isOpen: pharmacyIsOpenNow(hours?[branches[i].branchId]),
                            onTap: () => _openDetails(branches[i]),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}
