import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/customer_profile.dart';
import '../../../providers/profile_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.initialProfile});

  /// Passed from the profile tab so we do not wait on a second network fetch.
  final CustomerProfile? initialProfile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  DateTime? _birthdate;
  var _busy = false;
  var _fieldsReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProfile;
    if (initial != null) {
      _applyProfile(initial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromProviders());
    }
  }

  void _hydrateFromProviders() {
    final profile = _profileFromProviders();
    if (profile != null && mounted) {
      setState(() => _applyProfile(profile));
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  void _applyProfile(CustomerProfile profile) {
    _firstName.text = profile.firstName;
    _middleName.text = profile.middleName ?? '';
    _lastName.text = profile.lastName;
    _mobile.text = profile.mobile;
    _email.text = profile.email;
    _birthdate = DateTime.tryParse(profile.birthdate);
    _fieldsReady = true;
  }

  CustomerProfile? _profileFromProviders() {
    final initial = widget.initialProfile;
    if (initial != null) return initial;
    final overview = ref.read(customerProfileOverviewProvider);
    if (overview.hasValue && overview.value != null) {
      return overview.value!.profile;
    }
    return ref.read(customerProfileProvider).value;
  }

  Future<void> _pickBirthdate() async {
    final initial = _birthdate ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _save() async {
    final birthdate = _birthdate;
    if (birthdate == null) {
      setState(() => _error = 'Select your birthdate.');
      return;
    }
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      setState(() => _error = 'First and last name are required.');
      return;
    }
    if (_mobile.text.trim().isEmpty) {
      setState(() => _error = 'Mobile number is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(profileServiceProvider).updateProfile(
            firstName: _firstName.text,
            middleName: _middleName.text,
            lastName: _lastName.text,
            mobile: _mobile.text,
            birthdate: birthdate,
          );
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

  @override
  Widget build(BuildContext context) {
    if (!_fieldsReady) {
      final overview = ref.watch(customerProfileOverviewProvider);
      final profileOnly = ref.watch(customerProfileProvider);
      final waiting = overview.isLoading && profileOnly.isLoading;

      if (waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final error = overview.hasError
          ? overview.error
          : profileOnly.hasError
              ? profileOnly.error
              : null;
      if (error != null) {
        return Scaffold(
          appBar: AppBar(title: const _AppBarTitle(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your personal details',
          )),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(customerProfileOverviewProvider);
                      ref.invalidate(customerProfileProvider);
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const _AppBarTitle(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Update your personal details',
        )),
        body: const Center(child: Text('Sign in to edit your profile.')),
      );
    }

    final birthLabel = _birthdate == null
        ? 'Select birthdate'
        : DateFormat.yMMMMd().format(_birthdate!);

    return Scaffold(
      appBar: AppBar(title: const _AppBarTitle(
        icon: Icons.edit_outlined,
        title: 'Edit Profile',
        subtitle: 'Update your personal details',
      )),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(
            controller: _firstName,
            label: 'First name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _middleName,
            label: 'Middle name (optional)',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _lastName,
            label: 'Last name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _mobile,
            label: 'Mobile (09XXXXXXXXX)',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _email,
            label: 'Email',
            enabled: false,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Email changes require support. Contact us if you need to update it.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Birthdate'),
            subtitle: Text(birthLabel),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _busy ? null : _pickBirthdate,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

// Reusable two-line AppBar title with icon used across profile sub-screens
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
