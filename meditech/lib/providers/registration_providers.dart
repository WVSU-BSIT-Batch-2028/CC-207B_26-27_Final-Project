import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy_application.dart';
import '../services/registration_service.dart';
import '../services/resubmit_service.dart';

// Gives screens the registration service
final registrationServiceProvider = Provider<RegistrationService>(
  (ref) => RegistrationService(http.Client()),
);

// Gives screens the resubmit service
final resubmitServiceProvider = Provider<ResubmitService>(
  (ref) => ResubmitService(Supabase.instance.client),
);

// What the registration screen needs to know right now
class RegistrationState {
  const RegistrationState({
    this.step = 0,
    this.submitting = false,
    this.error,
    this.fieldErrors = const {},
    this.applicationId,
  });

  final int step; // 0 to 3
  final bool submitting;
  final String? error;
  final Map<String, String> fieldErrors;
  final String? applicationId; // set once submitted or resubmitted

  RegistrationState copyWith({
    int? step,
    bool? submitting,
    String? error,
    Map<String, String>? fieldErrors,
    String? applicationId,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      submitting: submitting ?? this.submitting,
      error: error,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      applicationId: applicationId ?? this.applicationId,
    );
  }
}

// Moves between steps, and submits or resubmits the application
class RegistrationController extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  // Go to a step (Continue, Back, or an Edit link)
  void goTo(int step) => state = state.copyWith(step: step);

  // Start fresh, for opening the form again
  void reset() => state = const RegistrationState();

  // Send a new application; on errors, jump back to the step with the problem
  Future<void> submit(PharmacyApplication application) async {
    state = state.copyWith(submitting: true, fieldErrors: {});
    try {
      final id = await ref.read(registrationServiceProvider).submit(application);
      state = state.copyWith(submitting: false, applicationId: id);
    } on RegistrationException catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e.message,
        fieldErrors: e.fieldErrors,
        step: _stepFor(e.fieldErrors),
      );
    }
  }

  // Send the edited application back for review
  Future<void> resubmit(
    Map<String, dynamic> details, {
    PickedDocument? ltoFile,
    PickedDocument? storefrontFile,
    required String displayId,
  }) async {
    state = state.copyWith(submitting: true, fieldErrors: {});
    try {
      await ref.read(resubmitServiceProvider).resubmit(
            details,
            ltoFile: ltoFile,
            storefrontFile: storefrontFile,
          );
      state = state.copyWith(submitting: false, applicationId: displayId);
    } on RegistrationException catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e.message,
        fieldErrors: e.fieldErrors,
        step: _stepFor(e.fieldErrors),
      );
    }
  }

  // Which step a field belongs to
  int _stepFor(Map<String, String> fields) {
    const license = {'lto_number', 'lto_expiry', 'lto_file', 'storefront_file'};
    const owner = {'first_name', 'middle_name', 'last_name', 'mobile', 'email', 'username', 'password'};
    if (fields.keys.any((k) => !license.contains(k) && !owner.contains(k))) return 0;
    if (fields.keys.any(license.contains)) return 1;
    if (fields.keys.any(owner.contains)) return 2;
    return state.step;
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(RegistrationController.new);