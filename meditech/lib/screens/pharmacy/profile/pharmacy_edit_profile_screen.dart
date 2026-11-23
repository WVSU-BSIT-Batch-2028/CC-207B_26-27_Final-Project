import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/pharmacy_staff_providers.dart';
import '../../../services/staff_profile_query.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

final _namePattern = RegExp(r"^[A-Za-zÑñ .'-]{2,50}$");

class PharmacyEditProfileScreen extends ConsumerStatefulWidget {
  const PharmacyEditProfileScreen({super.key});

  @override
  ConsumerState<PharmacyEditProfileScreen> createState() =>
      _PharmacyEditProfileScreenState();
}

class _PharmacyEditProfileScreenState
    extends ConsumerState<PharmacyEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  var _ready = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(pharmacyStaffProfileProvider).value;
    if (profile != null) _apply(profile);
  }

  void _apply(PharmacyStaffProfile profile) {
    _firstName.text = profile.firstName;
    _middleName.text = profile.middleName ?? '';
    _lastName.text = profile.lastName;
    _ready = true;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await updateMyStaffProfile(
        Supabase.instance.client,
        firstName: _firstName.text,
        middleName: _middleName.text,
        lastName: _lastName.text,
      );
      ref.invalidate(pharmacyStaffProfileProvider);
      if (!mounted) return;
      context.pop(true);
    } on PostgrestException catch (error) {
      setState(() => _error = AppFailure.fromPostgrest(error).message);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(pharmacyStaffProfileProvider);
    if (!_ready) {
      profileAsync.whenData((profile) {
        if (profile != null && !_ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _apply(profile));
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Edit profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update the name shown in the pharmacy app. Your username stays the same.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_ready)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: 'First name',
                        controller: _firstName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Middle name (optional)',
                        controller: _middleName,
                        validator: (v) {
                          final trimmed = (v ?? '').trim();
                          if (trimmed.isEmpty) return null;
                          return _namePattern.hasMatch(trimmed)
                              ? null
                              : 'Enter 2 to 50 letters.';
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Last name',
                        controller: _lastName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(_busy ? 'Saving…' : 'Save'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: _busy ? null : () => context.pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
