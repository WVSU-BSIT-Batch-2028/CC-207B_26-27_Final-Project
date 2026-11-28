import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../models/child_validators.dart';
import '../../routing/app_router.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';
import 'widgets/child_widgets.dart';

/// Form screen for creating or editing a child profile.
///
/// Caregivers provide either a birth month and year (used to derive the age
/// band) or select an [AgeBand] directly. Client-side validation runs before
/// submission, and server-side field errors are mapped back to each input.
class AddChildScreen extends StatefulWidget {
  /// Creates an [AddChildScreen].
  ///
  /// Pass [child] to edit an existing profile instead of creating a new one.
  const AddChildScreen({super.key, this.child, this.childrenService});

  /// The profile to edit, or `null` when adding a new child.
  final Child? child;

  /// Optional service override used to save profiles.
  ///
  /// When `null`, this screen builds a [ChildrenService] from [AuthScope].
  final ChildrenService? childrenService;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  // Supported ages cover 0 to 71 months (under 6 years), spanning at most 7
  // calendar years including the current year.
  static const _yearCount = 7;

  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  int? _birthYear;
  int? _birthMonth;

  bool _useAgeBand = false;
  AgeBand? _ageBand;

  bool get _isEditing => widget.child != null;

  @override
  void initState() {
    super.initState();
    final child = widget.child;
    if (child == null) {
      return;
    }
    _nicknameController.text = child.nickname;

    // Birth dates are stored in YYYY-MM format (for example, '2025-03').
    final parts = child.birthMonthYear?.split('-');
    final year = parts == null ? null : int.tryParse(parts[0]);
    final month = parts == null || parts.length < 2
        ? null
        : int.tryParse(parts[1]);
    if (year != null && month != null) {
      _birthYear = year;
      _birthMonth = month;
    } else {
      // No birth date was saved, so fall back to the direct age-band selector.
      _useAgeBand = true;
      _ageBand = ageBandForCode(child.ageBand);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool _saving = false;
  String? _errorMessage;
  bool _offline = false;

  // Server field errors keyed by API field name ('nickname', 'birthMonthYear', 'ageBand').
  Map<String, String> _fieldErrors = const {};

  static const _formFields = {'nickname', 'birthMonthYear', 'ageBand'};

  // Maps server validation errors to matching form fields; unmapped errors
  // (such as profile count limits) are displayed above the Save button.
  void _showServerErrors(ApiException error) {
    final fieldErrors = <String, String>{};
    String? otherError;
    for (final detail in error.details) {
      final field = detail['field'];
      final issue = detail['issue'];
      if (field is! String || issue is! String) {
        continue;
      }
      if (_formFields.contains(field)) {
        fieldErrors[field] = issue;
      } else {
        otherError ??= issue;
      }
    }
    setState(() {
      _fieldErrors = fieldErrors;
      _errorMessage = fieldErrors.isEmpty
          ? (otherError ?? error.message)
          : otherError;
    });
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }
    setState(() {
      _fieldErrors = Map.of(_fieldErrors)..remove(field);
    });
  }

  // Validates the form and submits either ageBand or birthMonthYear (never
  // both, matching the API contract), then updates the active child.
  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    // Capture context-dependent references before awaiting network I/O.
    final session = AuthScope.of(context);
    final navigator = Navigator.of(context);
    final childrenService =
        widget.childrenService ??
        ChildrenService(apiClient: AuthScope.apiClientOf(context));

    // Reset the offline flag before submitting so the save request retries
    // the connection instead of short-circuiting immediately.
    final apiClient = childrenService.apiClient;
    if (apiClient.isOffline) {
      apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final nickname = _nicknameController.text.trim();
      final ageBand = _useAgeBand ? _ageBand!.code : null;
      final birthMonthYear = _useAgeBand ? null : _birthMonthYear;
      final editing = widget.child;

      final Child child;
      if (editing == null) {
        child = await childrenService.createChild(
          nickname: nickname,
          ageBand: ageBand,
          birthMonthYear: birthMonthYear,
        );
        // Make the newly created profile the active child.
        session.setActiveChild(child);
      } else {
        child = await childrenService.updateChild(
          id: editing.id,
          nickname: nickname,
          ageBand: ageBand,
          birthMonthYear: birthMonthYear,
        );
        // Keep the shell header chip synced if the active child was edited.
        if (session.activeChild?.id == child.id) {
          session.setActiveChild(child);
        }
      }
      if (!mounted) {
        return;
      }
      if (navigator.canPop()) {
        navigator.pop(child);
      } else {
        navigator.pushReplacementNamed(AppRouter.initialRoute);
      }
    } on NoConnectionApiException {
      // Retain form inputs so the caregiver can retry saving once reconnected.
      if (!mounted) {
        return;
      }
      setState(() {
        _offline = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showServerErrors(error);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _offline = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // Formats the selected birth year and month into the API's YYYY-MM string.
  String get _birthMonthYear {
    final month = _birthMonth!.toString().padLeft(2, '0');
    return '$_birthYear-$month';
  }

  // Derives the matching AgeBand for the selected birth year and month.
  AgeBand? get _derivedBand {
    final year = _birthYear;
    final month = _birthMonth;
    if (year == null || month == null) {
      return null;
    }
    final months = ageInMonths(
      birthYear: year,
      birthMonth: month,
      now: DateTime.now(),
    );
    return ageBandForMonths(months);
  }

  String? _validateBirthYear(int? year) {
    if (year == null) {
      return 'Choose a year';
    }
    final month = _birthMonth;
    if (month == null) {
      // The birth month dropdown renders its own required-field error.
      return null;
    }
    return validateBirthMonthYear(
      year: year,
      month: month,
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final band = _derivedBand;
    final years = [for (var i = 0; i < _yearCount; i++) currentYear - i];
    // A dropdown must contain its selected value. An edited child who is
    // now older than the list covers keeps their year, and the birth date
    // check then explains that the age is out of range.
    final birthYear = _birthYear;
    if (birthYear != null && !years.contains(birthYear)) {
      years.add(birthYear);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit child profile' : 'Add child profile'),
      ),
      body: SafeArea(
        child: ResponsiveContentBox(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.space16),
              children: [
                TextFormField(
                  controller: _nicknameController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    errorText: _fieldErrors['nickname'],
                  ),
                  validator: validateNickname,
                  onChanged: (_) => _clearFieldError('nickname'),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.space16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Choose an age band instead'),
                  value: _useAgeBand,
                  onChanged: (value) {
                    setState(() {
                      _useAgeBand = value;
                      _fieldErrors = Map.of(_fieldErrors)
                        ..remove('ageBand')
                        ..remove('birthMonthYear');
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.space8),
                // Only one way of giving the age is on screen, so the form only
                // checks that one. The API needs exactly one of the two.
                if (_useAgeBand)
                  DropdownButtonFormField<AgeBand>(
                    isExpanded: true,
                    initialValue: _ageBand,
                    decoration: InputDecoration(
                      labelText: 'Age band',
                      errorText: _fieldErrors['ageBand'],
                    ),
                    items: [
                      for (final ageBand in ageBands)
                        DropdownMenuItem(
                          value: ageBand,
                          child: Text(ageBand.label),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _ageBand = value;
                      });
                      _clearFieldError('ageBand');
                    },
                    validator: (value) =>
                        value == null ? 'Choose an age band' : null,
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _birthMonth,
                    decoration: const InputDecoration(labelText: 'Birth month'),
                    items: [
                      for (var month = 1; month <= 12; month++)
                        DropdownMenuItem(
                          value: month,
                          child: Text(
                            DateFormat.MMMM().format(DateTime(2000, month)),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _birthMonth = value;
                      });
                      _clearFieldError('birthMonthYear');
                    },
                    validator: (value) =>
                        value == null ? 'Choose a month' : null,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _birthYear,
                    // A server error about the birth date shows here, under
                    // the year, where the local birth date check shows too.
                    decoration: InputDecoration(
                      labelText: 'Birth year',
                      errorText: _fieldErrors['birthMonthYear'],
                    ),
                    items: [
                      for (final year in years)
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _birthYear = value;
                      });
                      _clearFieldError('birthMonthYear');
                    },
                    validator: _validateBirthYear,
                  ),
                  if (band != null) ...[
                    const SizedBox(height: AppSpacing.space8),
                    Text('Age band: ${band.label}'),
                  ],
                ],
                const SizedBox(height: AppSpacing.space16),
                if (_offline) ...[
                  const ChildOfflineNotice(),
                  const SizedBox(height: AppSpacing.space16),
                ],
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textError),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                ],
                SizedBox(
                  height: AppSizes.touchTarget,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.surfaceCard,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.space20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.accountSettings,
                      ),
                      child: const Text(
                        'Need to delete this profile and its records? Manage in Settings',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
