// Edit profile: change your name, town and a short "about" text (like the
// website's Edit profile). Validated before saving, with the
// "Discard changes?" question when leaving with unsaved edits.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/labeled_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';

/// Form for the logged-in user's own profile. Closes with `true` when saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: AuthService.currentUser!.name,
  );
  late final _aboutController = TextEditingController(
    text: AuthService.currentUser!.about,
  );
  late String? _town = kTowns.contains(AuthService.currentUser!.town)
      ? AuthService.currentUser!.town
      : null;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await AuthService().updateProfile(
        name: _nameController.text,
        town: _town!,
        about: _aboutController.text,
      );
      if (!mounted) return;
      showMessage(context, 'Profile saved.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFarmer = AuthService.currentUser!.isFarmer;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDiscardChangesDialog(context);
        if (discard && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_hasChanges) setState(() => _hasChanges = true);
          },
          child: ResponsiveBody(
            maxWidth: AppSizes.maxFormWidth,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                const PageHeader(
                  eyebrow: 'Your account',
                  title: 'Edit profile',
                ),
                const SizedBox(height: AppSizes.sectionGap),
                const RequiredNote(),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Full name',
                  isRequired: true,
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.name,
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Town',
                  isRequired: true,
                  help: isFarmer
                      ? 'New crops you post use this town by default.'
                      : 'Farmers see this town on your requests.',
                  child: DropdownField(
                    label: null,
                    items: kTowns,
                    value: _town,
                    onChanged: (value) => setState(() {
                      _town = value;
                      _hasChanges = true;
                    }),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: isFarmer ? 'About you and your farm' : 'About you',
                  child: TextFormField(
                    controller: _aboutController,
                    maxLines: 4,
                    maxLength: 300,
                    validator: Validators.maxLength(300),
                    decoration: InputDecoration(
                      hintText: isFarmer
                          ? 'e.g. Family farm in Leon, vegetables all year'
                          : 'e.g. Carinderia owner in Iloilo City',
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.small),
                const NoticeBox(
                  kind: NoticeKind.info,
                  message:
                      'Crops and requests you already posted keep the name '
                      'they were posted with.',
                ),
                const SizedBox(height: AppSizes.sectionGap),
                LoadingButton(
                  label: 'Save profile',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
                const SizedBox(height: AppSizes.small),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text(AppStrings.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
