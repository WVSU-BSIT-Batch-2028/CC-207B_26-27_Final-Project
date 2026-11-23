import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/branch_settings.dart';
import '../../../providers/branch_settings_providers.dart';
import '../../../providers/pharmacy_staff_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/pharmacy/pharmacy_user_profile_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Branch Settings screen (Ph-36)
// Allows the Pharmacy Owner to view/edit branch details and owner PRC license.
// Other staff have read-only access.
class BranchSettingsScreen extends ConsumerStatefulWidget {
  const BranchSettingsScreen({super.key});

  @override
  ConsumerState<BranchSettingsScreen> createState() => _BranchSettingsScreenState();
}

class _BranchSettingsScreenState extends ConsumerState<BranchSettingsScreen> {
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _hoursController = TextEditingController();
  final _prcNumberController = TextEditingController();

  DateTime? _prcExpiry;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    _contactController.dispose();
    _hoursController.dispose();
    _prcNumberController.dispose();
    super.dispose();
  }

  void _populate(BranchSettings settings) {
    if (_initialized) return;
    _addressController.text = settings.address;
    _contactController.text = settings.contactNumber;
    _hoursController.text = settings.operatingHours;
    _prcNumberController.text = settings.ownerPrcLicense ?? '';
    _prcExpiry = settings.ownerPrcExpiry;
    _initialized = true;
  }

  Future<void> _save(BranchSettings settings) async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(branchSettingsServiceProvider);
      final isOwner = ref.read(sessionProvider)?.role == 'owner';
      await service.updateSettings(
        branchId: settings.branchId,
        address: _addressController.text.trim(),
        contactNumber: _contactController.text.trim(),
        operatingHours: _hoursController.text.trim(),
        ownerPrcLicense: _prcNumberController.text.trim(),
        ownerPrcExpiry: _prcExpiry,
        updateBranchDetails: isOwner,
      );

      ref.invalidate(branchSettingsProvider);
      ref.invalidate(pharmacyStaffProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(branchSettingsProvider);
    final profile = ref.watch(pharmacyStaffProfileProvider).asData?.value;
    final account = ref.watch(sessionProvider);
    final isOwner = account?.role == 'owner';
    final canEditPrc =
        isOwner || account?.role == 'pharmacist' || account?.role == 'staff';
    final showSave = isOwner || canEditPrc;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncView<BranchSettings>(
        value: settingsAsync,
        onRetry: () {
          _initialized = false;
          ref.invalidate(branchSettingsProvider);
        },
        builder: (settings) {
          _populate(settings);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Branch address, contact, hours, and pharmacist license on file.',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (profile != null) ...[
                      PharmacyUserProfileCard(
                        profile: profile,
                        onChangePassword: () {
                          if (GoRouter.maybeOf(context) != null) {
                            context.push('/change-password');
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    PharmacySettingsSectionCard(
                      title: 'Branch Details',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Pharmacy name',
                                initialValue: settings.pharmacyName,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildTextField(
                                label: 'Branch name',
                                initialValue: settings.branchName,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildEditableField(
                          label: 'Address',
                          controller: _addressController,
                          enabled: isOwner,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditableField(
                                label: 'Contact number',
                                controller: _contactController,
                                enabled: isOwner,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildEditableField(
                                label: 'Operating hours',
                                controller: _hoursController,
                                enabled: isOwner,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Map location indicator
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Map pin used for patient directions',
                                  style: TextStyle(fontSize: 13, color: AppColors.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // FDA LTO Note
                        Text(
                          'FDA License to Operate: ${settings.fdaLto} · verified by Administrator',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Owner PRC License Card
                    PharmacySettingsSectionCard(
                      title: 'PRC license (pharmacists & owner-pharmacists)',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditableField(
                                label: 'PRC license number',
                                controller: _prcNumberController,
                                enabled: canEditPrc,
                                hintText: '7 digits',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'License expiry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: !canEditPrc
                                        ? null
                                        : () async {
                                            final now = DateTime.now();
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _prcExpiry ?? now,
                                              firstDate: now,
                                              lastDate: now.add(const Duration(days: 365 * 10)),
                                            );
                                            if (picked != null) {
                                              setState(() => _prcExpiry = picked);
                                            }
                                          },
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: canEditPrc ? Colors.white : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _prcExpiry != null
                                            ? '${_prcExpiry!.month}/${_prcExpiry!.day}/${_prcExpiry!.year}'
                                            : 'mm/dd/yyyy',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _prcExpiry != null ? AppColors.text : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (showSave)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _isSaving ? null : () => _save(settings),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save changes'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            initialValue,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            filled: !enabled,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
