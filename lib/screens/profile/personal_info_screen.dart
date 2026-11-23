import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/validators.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/h360_button.dart';
import '../../widgets/menu_tile.dart';

/// Personal Information for both roles. Read-only until "Edit" is pressed;
/// saving validates the form and stores the values.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const List<String> _genders = ['Male', 'Female', 'Prefer not to say'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _birth = TextEditingController();
  final TextEditingController _address = TextEditingController();

  UserProfile? _original;
  String _gender = '';
  String _birthIso = '';
  bool _editing = false;
  bool _saving = false;

  bool get _isPatient => widget.role == UserRole.patient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _birth.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await ProfileService.instance.load(widget.role);
    if (!mounted) return;
    setState(() {
      _original = p;
      _fill(p);
    });
  }

  void _fill(UserProfile p) {
    _name.text = p.fullName;
    _email.text = p.email;
    _mobile.text = p.mobile;
    _address.text = p.address;
    _gender = p.gender;
    _birthIso = p.birthDate;
    final parsed = DateTime.tryParse(p.birthDate);
    _birth.text = parsed == null ? '' : formatLongDate(parsed);
  }

  Future<void> _pickBirthDate() async {
    final initial = DateTime.tryParse(_birthIso) ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _birthIso = dateKey(picked);
      _birth.text = formatLongDate(picked);
    });
  }

  void _cancel() {
    final p = _original;
    setState(() {
      if (p != null) _fill(p);
      _editing = false;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final base = _original;
    if (base == null) return;

    setState(() => _saving = true);
    final updated = base.copyWith(
      fullName: _name.text.trim(),
      mobile: _mobile.text.trim(),
      birthDate: _birthIso,
      gender: _gender,
      address: _address.text.trim(),
    );
    await ProfileService.instance.save(widget.role, updated);
    if (!mounted) return;

    setState(() {
      _original = updated;
      _saving = false;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal information updated.')),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final dialogKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Form(
              key: dialogKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: obscure,
                    decoration: AppTheme.inputDecoration(label: 'Current Password'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your current password.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: obscure,
                    decoration: AppTheme.inputDecoration(
                      label: 'New Password',
                      hint: '8+ chars, A-Z, a-z, 0-9',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    decoration: AppTheme.inputDecoration(label: 'Confirm New Password'),
                    validator: (v) {
                      if (v != newCtrl.text) return 'Passwords do not match.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(dialogKey.currentState?.validate() ?? false)) return;
                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });
                      try {
                        await AuthService().changePassword(
                          currentPassword: currentCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Password updated successfully.')),
                          );
                        }
                      } on AuthException catch (e) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = e.message;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _original;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Personal Information'),
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      controller: _name,
                      label: 'Full name',
                      readOnly: !_editing,
                      validator: Validators.fullName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _field(
                      controller: _email,
                      label: 'Email',
                      readOnly: true,
                      helper: 'Your email is tied to your account.',
                    ),
                    _field(
                      controller: _mobile,
                      label: 'Mobile number',
                      readOnly: !_editing,
                      keyboardType: TextInputType.phone,
                      validator: (v) => Validators.mobile(v, isRequired: !_isPatient),
                    ),
                    if (_isPatient)
                      _field(
                        controller: _birth,
                        label: 'Date of birth',
                        readOnly: true,
                        onTap: _editing ? _pickBirthDate : null,
                        suffix: const Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Gender', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in _genders)
                            ChoiceChip(
                              label: Text(g),
                              selected: _gender == g,
                              onSelected: _editing ? (_) => setState(() => _gender = g) : null,
                              selectedColor: AppColors.primary.withOpacity(0.15),
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: AppColors.border),
                              labelStyle: TextStyle(
                                color: _gender == g ? AppColors.primary : AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _field(
                      controller: _address,
                      label: 'Address',
                      readOnly: !_editing,
                      validator: Validators.address,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (!_editing)
                      H360Button(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        onPressed: () => setState(() => _editing = true),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : _cancel,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: H360Button(label: 'Save changes', isLoading: _saving, onPressed: _save),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Security', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                    ),
                    MenuTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Change Password',
                      onTap: _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool readOnly,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    VoidCallback? onTap,
    Widget? suffix,
    String? helper,
    int maxLines = 1,
  }) {
    final decoration = AppTheme.inputDecoration(label: label).copyWith(
      suffixIcon: suffix,
      helperText: helper,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        showCursor: !readOnly,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        onTap: onTap,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: decoration,
      ),
    );
  }
}