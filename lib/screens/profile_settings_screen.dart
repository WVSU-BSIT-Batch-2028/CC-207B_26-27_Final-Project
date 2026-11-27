import 'dart:async';

import 'package:flutter/material.dart';

import '../foodwise_theme.dart';

import 'package:image_picker/image_picker.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';

import '../services/auth_service.dart';

enum _FeedbackKind { success, info, warning, error }

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Map<String, dynamic>? _profile;
  String _originalName = '';
  String _originalPhone = '';
  bool _hasPhoneColumn = false;
  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _uploadingAvatar = false;
  bool _removingAvatar = false;
  bool _sendingResetEmail = false;
  int _resetCooldownRemaining = 0;
  Timer? _resetCooldownTimer;

  String? _profileError;
  String? _profileFeedback;
  String? _avatarFeedback;
  String? _securityFeedback;
  _FeedbackKind _profileFeedbackKind = _FeedbackKind.info;
  _FeedbackKind _avatarFeedbackKind = _FeedbackKind.info;
  _FeedbackKind _securityFeedbackKind = _FeedbackKind.info;

  bool get _profileDirty =>
      _nameController.text.trim() != _originalName ||
      (_hasPhoneColumn && _phoneController.text.trim() != _originalPhone);

  bool get _isSaving => _savingProfile || _uploadingAvatar || _removingAvatar;

  bool get _canSaveProfile =>
      !_loadingProfile &&
      _profileError == null &&
      !_savingProfile &&
      !_uploadingAvatar &&
      !_removingAvatar &&
      _profileDirty &&
      _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    _phoneController.addListener(_refresh);
    _loadProfile();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _resetCooldownTimer?.cancel();
    _nameController.removeListener(_refresh);
    _phoneController.removeListener(_refresh);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });

    try {
      final profile = await AuthService.getProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() => _profileError = 'Student profile not found.');
        return;
      }

      final name = profile['full_name']?.toString().trim() ?? '';
      final hasPhone = profile.containsKey('phone');
      final phone = hasPhone ? (profile['phone']?.toString() ?? '') : '';

      // Update controllers before the state update so their listeners do not
      // trigger a nested setState call.
      _nameController.text = name;
      _phoneController.text = phone;
      setState(() {
        _profile = profile;
        _hasPhoneColumn = hasPhone;
        _originalName = name;
        _originalPhone = phone.trim();
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _profileError = _friendlyError(
          error,
          fallback: 'We couldn’t load your profile. Check your connection and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_canSaveProfile) return;

    final cleanName = _nameController.text.trim();
    final cleanPhone = _phoneController.text.trim();

    setState(() {
      _savingProfile = true;
      _profileFeedback = null;
    });
    try {
      final updated = await AuthService.updateProfile(
        fullName: cleanName,
        phone: _hasPhoneColumn ? cleanPhone : null,
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _originalName = cleanName;
        if (_hasPhoneColumn) _originalPhone = cleanPhone;
        _profileFeedback = 'Your profile information has been saved.';
        _profileFeedbackKind = _FeedbackKind.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileFeedback = _friendlyError(
          error,
          fallback: 'We couldn’t save your profile changes. Your entries are still here; please try again.',
        );
        _profileFeedbackKind = _FeedbackKind.error;
      });
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (_uploadingAvatar || _removingAvatar || _savingProfile) return;

    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _avatarFeedback = 'We couldn’t open your photos. Check your browser or device permissions and try again.';
        _avatarFeedbackKind = _FeedbackKind.error;
      });
      return;
    }

    // Closing the picker is not an error and should not show a message.
    if (image == null || !mounted) return;

    setState(() {
      _uploadingAvatar = true;
      _avatarFeedback = null;
    });

    try {
      final updated = await AuthService.uploadProfileAvatar(image);
      if (!mounted) return;
      final photoIsReady =
          updated['avatar_url']?.toString().isNotEmpty ?? false;
      setState(() {
        _profile = updated;
        _avatarFeedback = photoIsReady
            ? 'Your profile photo has been updated.'
            : 'Your photo was uploaded, but FoodWise couldn’t display it yet. Please check the avatar storage read permissions.';
        _avatarFeedbackKind = photoIsReady
            ? _FeedbackKind.success
            : _FeedbackKind.warning;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarFeedback = _friendlyError(
          error,
          fallback: 'We couldn’t update your profile photo. Your existing photo is still in place. Please try again.',
        );
        _avatarFeedbackKind = _FeedbackKind.error;
      });
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_uploadingAvatar || _removingAvatar || _savingProfile) return;

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FoodWiseColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FoodWiseRadius.large),
        ),
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your profile will show your initials instead. You can add another photo anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: FoodWiseColors.deepOrange,
            ),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;

    setState(() {
      _removingAvatar = true;
      _avatarFeedback = null;
    });

    try {
      final updated = await AuthService.removeProfileAvatar();
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _avatarFeedback = 'Your profile photo has been removed.';
        _avatarFeedbackKind = _FeedbackKind.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarFeedback = _friendlyError(
          error,
          fallback: 'We couldn’t remove your profile photo. Your current photo has been kept. Please try again.',
        );
        _avatarFeedbackKind = _FeedbackKind.error;
      });
    } finally {
      if (mounted) setState(() => _removingAvatar = false);
    }
  }

  Widget _avatarPlaceholder() {
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';

    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: FoodWiseColors.lightOrange,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: FoodWiseColors.deepOrange,
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _profilePhotoEditor() {
    final avatarUrl = _profile?['avatar_url']?.toString().trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final busy = _uploadingAvatar || _removingAvatar;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: 104,
                height: 104,
                child: hasAvatar
                    ? Image.network(
                        avatarUrl,
                        key: ValueKey(avatarUrl),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) =>
                            loadingProgress == null
                            ? child
                            : _avatarPlaceholder(),
                        errorBuilder: (context, error, stackTrace) =>
                            _avatarPlaceholder(),
                      )
                    : _avatarPlaceholder(),
              ),
            ),
            if (busy)
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: FoodWiseColors.shadow.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: FoodWiseColors.surface,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: busy || _savingProfile ? null : _changeProfilePhoto,
              icon: Icon(
                _uploadingAvatar
                    ? Icons.hourglass_top_rounded
                    : Icons.photo_camera_back_outlined,
                size: 18,
              ),
              label: Text(
                _uploadingAvatar ? 'Uploading photo...' : 'Change photo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: FoodWiseColors.deepOrange,
                side: const BorderSide(color: FoodWiseColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FoodWiseRadius.compact),
                ),
              ),
            ),
            if (hasAvatar)
              TextButton.icon(
                onPressed: busy || _savingProfile ? null : _removeProfilePhoto,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(_removingAvatar ? 'Removing...' : 'Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: FoodWiseColors.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'JPG, PNG, or WebP · Maximum 5 MB',
          style: TextStyle(
            color: FoodWiseColors.muted,
            fontSize: FoodWiseTypeSize.overline,
          ),
        ),
      ],
    );
  }

  Future<void> _requestLeave() async {
    if (_isSaving) return;
    if (!_profileDirty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FoodWiseColors.surface,
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your last saved profile information will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (!mounted || discard != true || _isSaving) return;

    _nameController.text = _originalName;
    _phoneController.text = _originalPhone;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _showChangeEmailDialog() async {
    final currentEmail = AuthService.currentUser?.email ?? '';
    final controller = TextEditingController(text: currentEmail);
    String? errorText;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FoodWiseColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FoodWiseRadius.panel),
          ),
          title: const Text('Change email address'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the new email address for your FoodWise account. Supabase may send a confirmation link before the change takes effect.',
                  style: TextStyle(
                    color: FoodWiseColors.muted,
                    height: 1.45,
                    fontSize: FoodWiseTypeSize.supporting,
                  ),
                ),
                const SizedBox(height: FoodWiseSpacing.lg),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'New email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: FoodWiseColors.error,
                      fontSize: FoodWiseTypeSize.caption,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(email);
                      if (!valid) {
                        setDialogState(
                          () => errorText = 'Enter a valid email address.',
                        );
                        return;
                      }
                      if (email.toLowerCase() == currentEmail.toLowerCase()) {
                        setDialogState(
                          () => errorText =
                              'This is already your current email address.',
                        );
                        return;
                      }

                      setDialogState(() {
                        busy = true;
                        errorText = null;
                      });
                      try {
                        await AuthService.updateEmail(email);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        setState(() {
                          _profileFeedback = 'Your email change request has been submitted. Follow the confirmation instructions sent to your email before the new address takes effect.';
                          _profileFeedbackKind = _FeedbackKind.info;
                        });
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(
                          () => errorText = _friendlyError(
                            error,
                            fallback: 'We couldn’t request this email change. Check the address and try again.',
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool busy = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FoodWiseColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FoodWiseRadius.panel),
          ),
          title: const Text('Change password'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify your current password, then choose a new password for your account.',
                    style: TextStyle(
                      color: FoodWiseColors.muted,
                      fontSize: FoodWiseTypeSize.supporting,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: FoodWiseSpacing.lg),
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: FoodWiseSpacing.md),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: FoodWiseSpacing.md),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Use at least 8 characters. Avoid reusing your current password.',
                    style: TextStyle(
                      color: FoodWiseColors.muted,
                      fontSize: FoodWiseTypeSize.caption,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: FoodWiseColors.error,
                        fontSize: FoodWiseTypeSize.caption,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final current = currentController.text;
                      final next = newController.text;
                      final confirm = confirmController.text;

                      if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                        setDialogState(
                          () => errorText = 'Complete all password fields.',
                        );
                        return;
                      }
                      if (next.length < 8) {
                        setDialogState(
                          () => errorText = 'Your new password must contain at least 8 characters.',
                        );
                        return;
                      }
                      if (next != confirm) {
                        setDialogState(
                          () => errorText = 'The new passwords do not match.',
                        );
                        return;
                      }
                      if (next == current) {
                        setDialogState(
                          () => errorText = 'Choose a password different from your current password.',
                        );
                        return;
                      }

                      setDialogState(() {
                        busy = true;
                        errorText = null;
                      });
                      try {
                        await AuthService.changePassword(
                          currentPassword: current,
                          newPassword: next,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        setState(() {
                          _securityFeedback = 'Your password has been updated.';
                          _securityFeedbackKind = _FeedbackKind.success;
                        });
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(
                          () => errorText = _friendlyAuthError(error),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  String _friendlyAuthError(Object error) => _friendlyError(
    error,
    fallback: 'We couldn’t update your password. Please check your details and try again.',
  );

  String _friendlyError(Object error, {required String fallback}) =>
      AppFeedback.fromError(
        error,
        fallback: fallback,
        invalidCredentialsMessage:
            'That current password doesn’t match. Check it and try again.',
      ).message;

  String _secondsLabel(int seconds) =>
      '$seconds ${seconds == 1 ? 'second' : 'seconds'}';

  void _startResetCooldown(int seconds) {
    if (seconds <= 0 || !mounted) return;

    _resetCooldownTimer?.cancel();
    setState(() {
      _resetCooldownRemaining = seconds;
      _securityFeedbackKind = _FeedbackKind.warning;
      _securityFeedback =
          'A reset email was requested recently. To protect your account, please wait before requesting another. You can try again in ${_secondsLabel(seconds)}.';
    });

    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resetCooldownRemaining <= 1) {
          _resetCooldownRemaining = 0;
          timer.cancel();
          _securityFeedbackKind = _FeedbackKind.info;
          _securityFeedback =
              'You can request another password reset email now.';
        } else {
          _resetCooldownRemaining--;
          _securityFeedbackKind = _FeedbackKind.warning;
          _securityFeedback =
              'A reset email was requested recently. To protect your account, please wait before requesting another. You can try again in ${_secondsLabel(_resetCooldownRemaining)}.';
        }
      });
    });
  }

  Future<void> _sendPasswordReset() async {
    if (_sendingResetEmail || _resetCooldownRemaining > 0) return;

    final email = AuthService.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() {
        _securityFeedback = 'We couldn’t find an email address for this account. Sign in again or contact support.';
        _securityFeedbackKind = _FeedbackKind.error;
      });
      return;
    }

    setState(() {
      _sendingResetEmail = true;
      _securityFeedback = null;
    });

    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _securityFeedback =
            'Password reset instructions have been sent to $email. Check your inbox and spam folder.';
        _securityFeedbackKind = _FeedbackKind.success;
      });
    } catch (error) {
      if (!mounted) return;

      final rawMessage = error.toString();
      final normalized = rawMessage.toLowerCase();
      final isRateLimited =
          normalized.contains('over_email_send_rate_limit') ||
          normalized.contains('email rate limit') ||
          normalized.contains('rate limit') ||
          normalized.contains('statuscode: 429') ||
          normalized.contains('status code: 429');

      if (isRateLimited) {
        final waitMatch = RegExp(
          r'after\s+(\d+)\s+seconds?',
          caseSensitive: false,
        ).firstMatch(rawMessage);
        final waitSeconds = int.tryParse(waitMatch?.group(1) ?? '');

        if (waitSeconds != null && waitSeconds > 0) {
          _startResetCooldown(waitSeconds);
        } else {
          setState(() {
            _securityFeedbackKind = _FeedbackKind.warning;
            _securityFeedback = 'A reset email was requested recently. Please wait a little while before trying again.';
          });
        }
      } else {
        setState(() {
          _securityFeedbackKind = _FeedbackKind.error;
          _securityFeedback = _friendlyError(
            error,
            fallback: 'We couldn’t send the reset email right now. Check your connection and try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sendingResetEmail = false);
    }
  }

  Widget _feedbackBanner({
    required String title,
    required String message,
    required _FeedbackKind kind,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FeedbackBanner(
      feedback: FeedbackData(
        title: title,
        message: message,
        type: FeedbackType.values.byName(kind.name),
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FoodWiseColors.surface,
      borderRadius: BorderRadius.circular(FoodWiseRadius.panel),
      border: Border.all(color: FoodWiseColors.border),
    ),
    child: child,
  );

  Widget _sectionHeader(IconData icon, String title, String description) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: FoodWiseColors.lightOrange,
          borderRadius: BorderRadius.circular(FoodWiseRadius.feedback),
        ),
        child: Icon(icon, color: FoodWiseColors.deepOrange, size: 23),
      ),
      const SizedBox(width: FoodWiseSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: FoodWiseTypeSize.bodyLarge,
                fontWeight: FontWeight.w800,
                color: FoodWiseColors.charcoal,
              ),
            ),
            const SizedBox(height: FoodWiseSpacing.xs),
            Text(
              description,
              style: const TextStyle(
                color: FoodWiseColors.muted,
                fontSize: FoodWiseTypeSize.supporting,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'Not available';
    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return 'Not available';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Icon(icon, color: FoodWiseColors.muted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: FoodWiseColors.muted,
              fontSize: FoodWiseTypeSize.supporting,
            ),
          ),
        ),
        const SizedBox(width: FoodWiseSpacing.sm),
        Flexible(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: FoodWiseColors.charcoal,
              fontWeight: FontWeight.w600,
              fontSize: FoodWiseTypeSize.supporting,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _profileSection() {
    if (_loadingProfile) {
      return _panel(
        child: const Center(
          child: CircularProgressIndicator(color: FoodWiseColors.deepOrange),
        ),
      );
    }

    if (_profileError != null) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedbackBanner(
              feedback: AppFeedback.failure(
                'Profile could not load',
                _profileError!,
              ),
            ),
            TextButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final user = AuthService.currentUser;
    final email = user?.email ?? '';
    final role = _profile?['role']?.toString() ?? 'Student';

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.person_outline_rounded,
            'Personal information',
            'Keep your FoodWise account details up to date.',
          ),
          const SizedBox(height: 18),
          Center(child: _profilePhotoEditor()),
          if (_avatarFeedback != null)
            _feedbackBanner(
              title: _avatarFeedbackKind == _FeedbackKind.success
                  ? 'Photo updated'
                  : _avatarFeedbackKind == _FeedbackKind.warning
                  ? 'Photo needs attention'
                  : 'We couldn’t update the photo',
              message: _avatarFeedback!,
              kind: _avatarFeedbackKind,
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          if (_hasPhoneColumn) ...[
            const SizedBox(height: FoodWiseSpacing.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'Enter your contact number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
          _infoRow(Icons.email_outlined, 'Email address', email),
          _infoRow(Icons.verified_user_outlined, 'Account role', role),
          _infoRow(
            Icons.calendar_month_outlined,
            'Member since',
            _formatDate(user?.createdAt),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _savingProfile ? null : _showChangeEmailDialog,
            icon: const Icon(Icons.alternate_email_rounded),
            label: const Text('Change email address'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FoodWiseColors.deepOrange,
              side: const BorderSide(color: FoodWiseColors.border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FoodWiseRadius.feedback),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _canSaveProfile ? _saveProfile : null,
            icon: _savingProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _savingProfile ? 'Saving profile...' : 'Save profile information',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: FoodWiseColors.deepOrange,
              foregroundColor: FoodWiseColors.surface,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FoodWiseRadius.feedback),
              ),
            ),
          ),
          if (!_hasPhoneColumn) ...[
            const SizedBox(height: 9),
            const Text(
              'Phone number editing is unavailable because your current profiles table does not return a phone column.',
              style: TextStyle(
                color: FoodWiseColors.muted,
                fontSize: FoodWiseTypeSize.overline,
                height: 1.4,
              ),
            ),
          ],
          if (_profileFeedback != null)
            _feedbackBanner(
              title: _profileFeedbackKind == _FeedbackKind.success
                  ? 'Changes saved'
                  : _profileFeedbackKind == _FeedbackKind.info
                  ? 'Next step'
                  : 'We need your attention',
              message: _profileFeedback!,
              kind: _profileFeedbackKind,
            ),
        ],
      ),
    );
  }

  Widget _securitySection() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.shield_outlined,
          'Password & security',
          'Protect your FoodWise account.',
        ),
        const SizedBox(height: FoodWiseSpacing.lg),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change password',
                    style: TextStyle(
                      color: FoodWiseColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: FoodWiseSpacing.xs),
                  Text(
                    'Verify your current password before setting a new one.',
                    style: TextStyle(
                      color: FoodWiseColors.muted,
                      fontSize: FoodWiseTypeSize.caption,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FoodWiseSpacing.sm),
            IconButton.filledTonal(
              onPressed: _showChangePasswordDialog,
              tooltip: 'Change password',
              style: IconButton.styleFrom(
                foregroundColor: FoodWiseColors.deepOrange,
                backgroundColor: FoodWiseColors.paleOrange,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
        const Divider(height: 24, color: FoodWiseColors.border),
        TextButton.icon(
          onPressed: (_sendingResetEmail || _resetCooldownRemaining > 0)
              ? null
              : _sendPasswordReset,
          icon: _sendingResetEmail
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_unread_outlined),
          label: Text(
            _sendingResetEmail
                ? 'Sending reset email...'
                : _resetCooldownRemaining > 0
                ? 'Try again in ${_secondsLabel(_resetCooldownRemaining)}'
                : 'Send password reset email',
          ),
          style: TextButton.styleFrom(
            foregroundColor: FoodWiseColors.deepOrange,
            disabledForegroundColor: FoodWiseColors.muted,
            alignment: Alignment.centerLeft,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'We’ll send reset instructions to your current account email address.',
            style: TextStyle(
              color: FoodWiseColors.muted,
              fontSize: FoodWiseTypeSize.caption,
              height: 1.4,
            ),
          ),
        ),
        if (_securityFeedback != null)
          _feedbackBanner(
            title: _securityFeedbackKind == _FeedbackKind.success
                ? 'Request complete'
                : _securityFeedbackKind == _FeedbackKind.warning
                ? 'Please wait'
                : _securityFeedbackKind == _FeedbackKind.info
                ? 'You’re ready to continue'
                : 'We couldn’t complete that request',
            message: _securityFeedback!,
            kind: _securityFeedbackKind,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_profileDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSaving) _requestLeave();
      },
      child: Scaffold(
        backgroundColor: FoodWiseColors.background,
        appBar: AppBar(
          backgroundColor: FoodWiseColors.background,
          foregroundColor: FoodWiseColors.charcoal,
          surfaceTintColor: FoodWiseColors.transparent,
          title: const Text(
            'Profile Settings',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          leading: BackButton(onPressed: _requestLeave),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  const Text(
                    'Your account',
                    style: TextStyle(
                      fontSize: FoodWiseTypeSize.pageTitle,
                      color: FoodWiseColors.charcoal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage your personal information and account security.',
                    style: TextStyle(color: FoodWiseColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  _profileSection(),
                  const SizedBox(height: 14),
                  _securitySection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
