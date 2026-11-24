import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/customer_saved_address.dart';
import '../../../providers/profile_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

final savedAddressesProvider = FutureProvider<List<CustomerSavedAddress>>((ref) {
  return ref.watch(profileServiceProvider).loadSavedAddresses();
});

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _AppBarTitle(
          icon: Icons.location_on_outlined,
          title: 'Saved Addresses',
          subtitle: 'Manage your pickup and delivery addresses',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Text('No saved addresses yet.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  title: Text(row.label),
                  subtitle: Text(row.singleLine),
                  trailing: row.isDefault
                      ? const Chip(label: Text('Default'))
                      : null,
                  onTap: () => _openEditor(context, ref, existing: row),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    CustomerSavedAddress? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _AddressEditorSheet(existing: existing),
    );
    if (saved == true) {
      ref.invalidate(savedAddressesProvider);
      ref.invalidate(customerProfileOverviewProvider);
    }
  }
}

class _AddressEditorSheet extends ConsumerStatefulWidget {
  const _AddressEditorSheet({this.existing});

  final CustomerSavedAddress? existing;

  @override
  ConsumerState<_AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends ConsumerState<_AddressEditorSheet> {
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _postal;
  var _isDefault = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? 'Home');
    _line1 = TextEditingController(text: existing?.line1 ?? '');
    _line2 = TextEditingController(text: existing?.line2 ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _province = TextEditingController(text: existing?.province ?? '');
    _postal = TextEditingController(text: existing?.postalCode ?? '');
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _province.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_line1.text.trim().isEmpty) {
      setState(() => _error = 'Street address is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final existing = widget.existing;
    final address = CustomerSavedAddress(
      id: existing?.id ?? '',
      label: _label.text.trim().isEmpty ? 'Home' : _label.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      province: _province.text.trim().isEmpty ? null : _province.text.trim(),
      postalCode: _postal.text.trim().isEmpty ? null : _postal.text.trim(),
      isDefault: _isDefault,
    );

    try {
      if (existing == null) {
        await ref.read(profileServiceProvider).saveAddress(address, isNew: true);
      } else {
        await ref.read(profileServiceProvider).saveAddress(address, isNew: false);
      }
      if (!mounted) return;
      context.pop(true);
    } on AppFailure catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileServiceProvider).deleteAddress(existing.id);
      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add address' : 'Edit address',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: _label, label: 'Label'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _line1, label: 'Street / building'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _line2, label: 'Unit / floor (optional)'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _city, label: 'City'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _province, label: 'Province'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _postal, label: 'Postal code'),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as default'),
              value: _isDefault,
              onChanged: _busy ? null : (value) => setState(() => _isDefault = value),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text('Remove address', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
