import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'dashboard_service.dart';

/// Error returned when appointment data cannot be loaded or updated.
class AppointmentException implements Exception {
  const AppointmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provides Firestore-backed appointment data and management operations.
class AppointmentService {
  AppointmentService._();

  static final AppointmentService instance = AppointmentService._();

  static const Duration changeRequestWindow = Duration(hours: 24);
  static const int maximumEditRequests = 2;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  // ---------------------------------------------------------------------------
  // Authentication and role helpers
  // ---------------------------------------------------------------------------

  String _requireSignedIn() {
    final user = _authService.currentUser;

    if (user == null) {
      throw const AppointmentException(
        'Please sign in to access appointments.',
      );
    }

    return user.uid;
  }

  Future<void> _requireRole(UserRole requiredRole) async {
    final uid = _requireSignedIn();
    final role = await _authService.getUserRole(uid);

    if (role != requiredRole) {
      throw AppointmentException(
        requiredRole == UserRole.doctor
            ? 'Only doctors can perform this action.'
            : 'Only patients can perform this action.',
      );
    }
  }

  /// Verifies that the selected Firebase account is a registered doctor.
  Future<void> _requireRegisteredDoctor(String doctorId) async {
    final normalizedId = doctorId.trim();

    if (normalizedId.isEmpty) {
      throw const AppointmentException(
        'Please select a valid registered doctor.',
      );
    }

    final doctorDocument =
        await _firestore.collection('users').doc(normalizedId).get();

    final doctorData = doctorDocument.data();

    if (!doctorDocument.exists || doctorData?['role'] != 'doctor') {
      throw const AppointmentException(
        'The selected doctor is not a registered doctor.',
      );
    }
  }

  Future<void> _prepareManagementAction() async {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't update the appointment. Please try again.",
      );
    }

    _requireSignedIn();
  }

  // ---------------------------------------------------------------------------
  // Fetch appointments
  // ---------------------------------------------------------------------------

  /// Retrieves only appointments belonging to the signed-in account.
  Future<List<Appointment>> fetchAppointments() async {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't load the appointments. Check your connection and try again.",
      );
    }

    try {
      final uid = _requireSignedIn();
      final role = await _authService.getUserRole(uid);

      Query<Map<String, dynamic>> query = _appointments;

      if (role == UserRole.patient) {
        query = query.where('patientId', isEqualTo: uid);
      } else if (role == UserRole.doctor) {
        // A doctor only sees the appointments assigned to them.
        // Required by the Firestore security rules.
        query = query.where('doctorId', isEqualTo: uid);
      } else {
        throw const AppointmentException(
          'Your account does not have permission to access appointments.',
        );
      }

      final snapshot = await query.get();

      final results = snapshot.docs
          .map(
            (document) => _fromFirestore(
              document.id,
              document.data(),
            ),
          )
          .toList();

      results.sort(
        (a, b) => a.dateTime.compareTo(b.dateTime),
      );

      return List.unmodifiable(results);
    } on AppointmentException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppointmentException(
        _firebaseErrorMessage(
          e,
          "We couldn't load the appointments. Check your connection and try again.",
        ),
      );
    } catch (_) {
      throw const AppointmentException(
        "We couldn't load the appointments. Please try again.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Create appointment
  // ---------------------------------------------------------------------------

  /// Creates an appointment for the currently signed-in patient.
  Future<Appointment> createAppointment({
    required String title,
    required String doctorId,
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    required bool isVideo,
    required double consultationFee,
    required bool reminderEnabled,
    String patientName = 'Demo Patient',
    String? patientId,
    String? meetingUrl,
  }) async {
    await _requireRole(UserRole.patient);

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't complete your booking. Please try again.",
      );
    }

    if (!dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Please select a future appointment date and time.',
      );
    }

    final uid = _requireSignedIn();

    if (patientId != null && patientId != uid) {
      throw const AppointmentException(
        'You can only create appointments for your own account.',
      );
    }

    try {
      await _requireRegisteredDoctor(doctorId);

      final userDocument = await _firestore.collection('users').doc(uid).get();

      final accountName = userDocument.data()?['fullName'] as String?;

      final resolvedPatientName =
          _authService.currentUser?.displayName?.trim().isNotEmpty == true
              ? _authService.currentUser!.displayName!.trim()
              : accountName?.trim().isNotEmpty == true
                  ? accountName!.trim()
                  : patientName == 'Demo Patient'
                      ? 'Patient'
                      : patientName;

      final bookedAt = DateTime.now();
      final document = _appointments.doc();

      final appointment = Appointment(
        id: document.id,
        title: title,
        patientName: resolvedPatientName,
        patientId: uid,
        doctorId: doctorId.trim(),
        doctorName: doctorName,
        specialty: specialty,
        dateTime: dateTime,
        location: location,
        isVideo: isVideo,
        status: AppointmentStatus.pending,
        consultationFee: consultationFee,
        reminderEnabled: reminderEnabled,
        meetingUrl: meetingUrl,
        bookedAt: bookedAt,
        editRequestCount: 0,
      );

      await document.set(_toFirestore(appointment));

      return appointment;
    } on AppointmentException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppointmentException(
        _firebaseErrorMessage(
          e,
          "We couldn't complete your booking. Please try again.",
        ),
      );
    } catch (_) {
      throw const AppointmentException(
        "We couldn't complete your booking. Please try again.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Doctor appointment actions
  // ---------------------------------------------------------------------------

  /// Confirms an appointment that is pending and not yet past.
  Future<Appointment> confirmAppointment(String appointmentId) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      _ensureUpcoming(appointment);

      if (appointment.status != AppointmentStatus.pending) {
        throw const AppointmentException(
          'Only pending appointments can be confirmed.',
        );
      }

      return _copyAppointment(
        appointment,
        status: AppointmentStatus.confirmed,
      );
    });
  }

  /// Cancels an appointment immediately from the doctor side.
  Future<Appointment> cancelAppointment(String appointmentId) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      _ensureUpcoming(appointment);

      if (appointment.status == AppointmentStatus.cancelled) {
        throw const AppointmentException(
          'This appointment has already been cancelled.',
        );
      }

      return _copyAppointment(
        appointment,
        status: AppointmentStatus.cancelled,
        clearChangeRequest: true,
      );
    });
  }

  /// Approves a patient's pending change request.
  Future<Appointment> approveAppointmentChange(
    String appointmentId,
  ) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      final request = appointment.changeRequest;

      _ensureUpcoming(appointment);

      if (appointment.status == AppointmentStatus.cancelled) {
        throw const AppointmentException(
          'A cancelled appointment cannot be changed.',
        );
      }

      if (request == null || request.status != ChangeRequestStatus.pending) {
        throw const AppointmentException(
          'There is no pending change request to approve.',
        );
      }

      if (!request.dateTime.isAfter(DateTime.now())) {
        throw const AppointmentException(
          'The requested appointment date and time has already passed.',
        );
      }

      final approvedRequest = _copyChangeRequest(
        request,
        status: ChangeRequestStatus.approved,
      );

      return _copyAppointment(
        appointment,
        title: 'Consultation with ${request.doctorName}',
        doctorId: request.doctorId,
        doctorName: request.doctorName,
        specialty: request.specialty,
        dateTime: request.dateTime,
        location: request.location,
        isVideo: request.isVideo,
        consultationFee: request.consultationFee,
        reminderEnabled: request.reminderEnabled,
        clearMeetingUrl: true,
        changeRequest: approvedRequest,
      );
    });
  }

  /// Rejects a patient's pending change request.
  Future<Appointment> rejectAppointmentChange(
    String appointmentId,
  ) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      final request = appointment.changeRequest;

      _ensureUpcoming(appointment);

      if (request == null || request.status != ChangeRequestStatus.pending) {
        throw const AppointmentException(
          'There is no pending change request to reject.',
        );
      }

      final rejectedRequest = _copyChangeRequest(
        request,
        status: ChangeRequestStatus.rejected,
      );

      return _copyAppointment(
        appointment,
        changeRequest: rejectedRequest,
      );
    });
  }

  /// Marks a past appointment as completed.
  Future<Appointment> markAppointmentDone(String appointmentId) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      _ensurePast(appointment);
      _ensureNotCancelled(appointment);

      return _copyAppointment(
        appointment,
        status: AppointmentStatus.done,
        outcome: AppointmentOutcome.done,
        clearChangeRequest: true,
      );
    });
  }

  /// Marks a past appointment as a no-show.
  Future<Appointment> markAppointmentNoShow(
    String appointmentId,
  ) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    return _updateAppointment(appointmentId, (appointment) {
      _ensurePast(appointment);
      _ensureNotCancelled(appointment);

      return _copyAppointment(
        appointment,
        status: AppointmentStatus.noShow,
        outcome: AppointmentOutcome.noShow,
        clearChangeRequest: true,
      );
    });
  }

  /// Updates the Google Meet URL of a confirmed video appointment.
  Future<Appointment> updateMeetingUrl({
    required String appointmentId,
    required String meetingUrl,
  }) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.doctor);

    final uri = Uri.tryParse(meetingUrl.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'meet.google.com' ||
        uri.pathSegments.isEmpty) {
      throw const AppointmentException(
        'Enter a valid Google Meet link.',
      );
    }

    return _updateAppointment(appointmentId, (appointment) {
      _ensureUpcoming(appointment);

      if (!appointment.isVideo) {
        throw const AppointmentException(
          'A meeting link can only be added to a video consultation.',
        );
      }

      if (appointment.status != AppointmentStatus.confirmed) {
        throw const AppointmentException(
          'Only confirmed appointments can receive a meeting link.',
        );
      }

      if (appointment.changeRequest?.status == ChangeRequestStatus.pending) {
        throw const AppointmentException(
          'Resolve the pending change request before updating the meeting link.',
        );
      }

      return _copyAppointment(
        appointment,
        meetingUrl: meetingUrl.trim(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Patient appointment actions
  // ---------------------------------------------------------------------------

  /// Allows a patient to cancel an upcoming appointment within 24 hours
  /// of its original booking time.
  Future<Appointment> cancelPatientAppointment(
    String appointmentId,
  ) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.patient);

    return _updateAppointment(appointmentId, (appointment) {
      _ensureWithinChangeRequestWindow(appointment);
      _ensureUpcoming(appointment);

      if (appointment.status == AppointmentStatus.cancelled) {
        throw const AppointmentException(
          'This appointment has already been cancelled.',
        );
      }

      return _copyAppointment(
        appointment,
        status: AppointmentStatus.cancelled,
        clearChangeRequest: true,
      );
    });
  }

  /// Submits a patient's request to change booking details.
  ///
  /// The original appointment remains unchanged until a doctor approves
  /// the request. Every submitted request consumes one edit request.
  Future<Appointment> requestAppointmentChange({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    required bool isVideo,
    required double consultationFee,
    required bool reminderEnabled,
  }) async {
    await _prepareManagementAction();
    await _requireRole(UserRole.patient);

    try {
      await _requireRegisteredDoctor(doctorId);

      return await _updateAppointment(appointmentId, (appointment) {
        _ensureWithinChangeRequestWindow(appointment);
        _ensureUpcoming(appointment);

        if (appointment.status == AppointmentStatus.cancelled) {
          throw const AppointmentException(
            'A cancelled appointment cannot be edited.',
          );
        }

        if (appointment.changeRequest?.status == ChangeRequestStatus.pending) {
          throw const AppointmentException(
            'You already have a change request waiting for doctor approval.',
          );
        }

        if (appointment.editRequestCount >= maximumEditRequests) {
          throw const AppointmentException(
            'You have used both allowed edit requests for this appointment.',
          );
        }

        if (!dateTime.isAfter(DateTime.now())) {
          throw const AppointmentException(
            'The requested appointment date and time must be in the future.',
          );
        }

        final request = AppointmentChangeRequest(
          doctorId: doctorId.trim(),
          doctorName: doctorName,
          specialty: specialty,
          dateTime: dateTime,
          location: location,
          isVideo: isVideo,
          consultationFee: consultationFee,
          reminderEnabled: reminderEnabled,
          requestedAt: DateTime.now(),
        );

        return _copyAppointment(
          appointment,
          changeRequest: request,
          editRequestCount: appointment.editRequestCount + 1,
        );
      });
    } on AppointmentException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppointmentException(
        _firebaseErrorMessage(
          e,
          "We couldn't update the appointment. Please try again.",
        ),
      );
    } catch (_) {
      throw const AppointmentException(
        "We couldn't update the appointment. Please try again.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore update helper
  // ---------------------------------------------------------------------------

  /// Reads, validates, and updates an appointment atomically.
  ///
  /// Verifies that the signed-in patient or assigned doctor owns
  /// the appointment before applying any changes.
  ///
  /// The transaction prevents simultaneous requests from overwriting
  /// each other's changes or bypassing the edit-request limit.
  Future<Appointment> _updateAppointment(
    String appointmentId,
    Appointment Function(Appointment appointment) update,
  ) async {
    try {
      final uid = _requireSignedIn();
      final role = await _authService.getUserRole(uid);

      if (role != UserRole.patient && role != UserRole.doctor) {
        throw const AppointmentException(
          'Your account does not have permission to update appointments.',
        );
      }

      // Resolve the linked patient ID if the account uses one.
      String? linkedPatientId;

      if (role == UserRole.patient) {
        final userDocument =
            await _firestore.collection('users').doc(uid).get();

        final patientIdValue = userDocument.data()?['patientId'];

        if (patientIdValue is String) {
          linkedPatientId = patientIdValue;
        }
      }

      final reference = _appointments.doc(appointmentId);

      return await _firestore.runTransaction<Appointment>(
        (transaction) async {
          final snapshot = await transaction.get(reference);

          if (!snapshot.exists || snapshot.data() == null) {
            throw const AppointmentException(
              'The appointment could not be found.',
            );
          }

          final appointment = _fromFirestore(
            snapshot.id,
            snapshot.data()!,
          );

          // Patients may update only appointments linked to their account.
          if (role == UserRole.patient) {
            final ownsAppointment = appointment.patientId == uid ||
                (linkedPatientId != null &&
                    appointment.patientId == linkedPatientId);

            if (!ownsAppointment) {
              throw const AppointmentException(
                'You do not have permission to update this appointment.',
              );
            }
          }

          // Doctors may update only appointments assigned to their UID.
          if (role == UserRole.doctor) {
            if (appointment.doctorId != uid) {
              throw const AppointmentException(
                'You are not the doctor assigned to this appointment.',
              );
            }
          }

          final updatedAppointment = update(appointment);

          transaction.update(
            reference,
            _toFirestore(updatedAppointment),
          );

          return updatedAppointment;
        },
      );
    } on AppointmentException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppointmentException(
        _firebaseErrorMessage(
          e,
          "We couldn't update the appointment. Please try again.",
        ),
      );
    } catch (_) {
      throw const AppointmentException(
        "We couldn't update the appointment. Please try again.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Appointment validation
  // ---------------------------------------------------------------------------

  void _ensureWithinChangeRequestWindow(Appointment appointment) {
    final bookedAt = appointment.bookedAt;

    if (bookedAt == null) {
      throw const AppointmentException(
        'The original booking time is unavailable. This appointment cannot be edited.',
      );
    }

    final elapsed = DateTime.now().difference(bookedAt);

    if (elapsed.isNegative || elapsed > changeRequestWindow) {
      throw const AppointmentException(
        'The 24-hour period for changing or cancelling this appointment has expired.',
      );
    }
  }

  void _ensureUpcoming(Appointment appointment) {
    if (!appointment.dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Past appointments cannot be changed.',
      );
    }

    if (appointment.outcome != AppointmentOutcome.none) {
      throw const AppointmentException(
        'This appointment already has a recorded outcome and cannot be changed.',
      );
    }
  }

  void _ensurePast(Appointment appointment) {
    if (appointment.dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Only past appointments can be marked as Done or No-show.',
      );
    }
  }

  void _ensureNotCancelled(Appointment appointment) {
    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'Cancelled appointments cannot receive an outcome.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Converts an appointment into the agreed Firestore document structure.
  Map<String, dynamic> _toFirestore(Appointment appointment) {
    return {
      'title': appointment.title,
      'patientId': appointment.patientId,
      'patientName': appointment.patientName,
      'doctorId': appointment.doctorId,
      'doctorName': appointment.doctorName,
      'specialty': appointment.specialty,
      'dateTime': Timestamp.fromDate(appointment.dateTime),
      'location': appointment.location,
      'status': appointment.status.name,
      'isVideo': appointment.isVideo,
      'meetLink': appointment.meetingUrl,
      'fee': appointment.consultationFee,
      'reminder': appointment.reminderEnabled,
      'bookedAt': appointment.bookedAt == null
          ? null
          : Timestamp.fromDate(appointment.bookedAt!),
      'outcome': appointment.outcome.name,
      'editRequestCount': appointment.editRequestCount,
      'changeRequest': appointment.changeRequest == null
          ? null
          : _changeRequestToFirestore(appointment.changeRequest!),
    };
  }

  Map<String, dynamic> _changeRequestToFirestore(
    AppointmentChangeRequest request,
  ) {
    return {
      'doctorId': request.doctorId,
      'doctorName': request.doctorName,
      'specialty': request.specialty,
      'dateTime': Timestamp.fromDate(request.dateTime),
      'location': request.location,
      'isVideo': request.isVideo,
      'fee': request.consultationFee,
      'reminder': request.reminderEnabled,
      'requestedAt': Timestamp.fromDate(request.requestedAt),
      'status': request.status.name,
    };
  }

  /// Converts a Firestore document into the existing Appointment model.
  Appointment _fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final requestData = data['changeRequest'];

    AppointmentChangeRequest? changeRequest;

    if (requestData is Map<String, dynamic>) {
      changeRequest = _changeRequestFromFirestore(requestData);
    } else if (requestData is Map) {
      changeRequest = _changeRequestFromFirestore(
        Map<String, dynamic>.from(requestData),
      );
    }

    return Appointment(
      id: id,
      title: data['title'] as String? ?? 'Consultation',
      patientName: data['patientName'] as String?,
      patientId: data['patientId'] as String?,
      doctorId: data['doctorId'] as String?,
      doctorName: data['doctorName'] as String? ?? 'Doctor',
      specialty: data['specialty'] as String? ?? 'General Consultation',
      dateTime: _readDate(data['dateTime']) ?? DateTime.now(),
      location: data['location'] as String? ?? '',
      isVideo: data['isVideo'] as bool? ?? false,
      status: _enumValue(
        AppointmentStatus.values,
        data['status'],
        AppointmentStatus.pending,
      ),
      consultationFee: _readDouble(data['fee']),
      reminderEnabled: data['reminder'] as bool? ?? false,
      meetingUrl: data['meetLink'] as String?,
      bookedAt: _readDate(data['bookedAt']),
      outcome: _enumValue(
        AppointmentOutcome.values,
        data['outcome'],
        AppointmentOutcome.none,
      ),
      changeRequest: changeRequest,
      editRequestCount: data['editRequestCount'] as int? ?? 0,
    );
  }

  AppointmentChangeRequest _changeRequestFromFirestore(
    Map<String, dynamic> data,
  ) {
    return AppointmentChangeRequest(
      doctorId: data['doctorId'] as String?,
      doctorName: data['doctorName'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
      dateTime: _readDate(data['dateTime']) ?? DateTime.now(),
      location: data['location'] as String? ?? '',
      isVideo: data['isVideo'] as bool? ?? false,
      consultationFee: _readDouble(data['fee']),
      reminderEnabled: data['reminder'] as bool? ?? false,
      requestedAt: _readDate(data['requestedAt']) ?? DateTime.now(),
      status: _enumValue(
        ChangeRequestStatus.values,
        data['status'],
        ChangeRequestStatus.pending,
      ),
    );
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  T _enumValue<T extends Enum>(
    List<T> values,
    dynamic value,
    T fallback,
  ) {
    for (final item in values) {
      if (item.name == value) {
        return item;
      }
    }

    return fallback;
  }

  // ---------------------------------------------------------------------------
  // Model copy helpers
  // ---------------------------------------------------------------------------

  Appointment _copyAppointment(
    Appointment appointment, {
    String? title,
    String? doctorId,
    String? doctorName,
    String? specialty,
    DateTime? dateTime,
    String? location,
    bool? isVideo,
    AppointmentStatus? status,
    double? consultationFee,
    bool? reminderEnabled,
    String? meetingUrl,
    AppointmentOutcome? outcome,
    AppointmentChangeRequest? changeRequest,
    int? editRequestCount,
    bool clearMeetingUrl = false,
    bool clearChangeRequest = false,
  }) {
    return Appointment(
      id: appointment.id,
      title: title ?? appointment.title,
      doctorId: doctorId ?? appointment.doctorId,
      doctorName: doctorName ?? appointment.doctorName,
      specialty: specialty ?? appointment.specialty,
      dateTime: dateTime ?? appointment.dateTime,
      location: location ?? appointment.location,
      isVideo: isVideo ?? appointment.isVideo,
      status: status ?? appointment.status,
      consultationFee: consultationFee ?? appointment.consultationFee,
      reminderEnabled: reminderEnabled ?? appointment.reminderEnabled,
      meetingUrl: clearMeetingUrl ? null : meetingUrl ?? appointment.meetingUrl,
      patientName: appointment.patientName,
      patientId: appointment.patientId,
      bookedAt: appointment.bookedAt,
      outcome: outcome ?? appointment.outcome,
      changeRequest: clearChangeRequest
          ? null
          : changeRequest ?? appointment.changeRequest,
      editRequestCount: editRequestCount ?? appointment.editRequestCount,
    );
  }

  AppointmentChangeRequest _copyChangeRequest(
    AppointmentChangeRequest request, {
    required ChangeRequestStatus status,
  }) {
    return AppointmentChangeRequest(
      doctorId: request.doctorId,
      doctorName: request.doctorName,
      specialty: request.specialty,
      dateTime: request.dateTime,
      location: request.location,
      isVideo: request.isVideo,
      consultationFee: request.consultationFee,
      reminderEnabled: request.reminderEnabled,
      requestedAt: request.requestedAt,
      status: status,
    );
  }

  // ---------------------------------------------------------------------------
  // Firebase error messages
  // ---------------------------------------------------------------------------

  String _firebaseErrorMessage(
    FirebaseException error,
    String fallback,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to access this appointment. Check your account role and Firestore security rules.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Check your internet connection and try again.';
      case 'not-found':
        return 'The appointment could not be found.';
      default:
        return error.message ?? fallback;
    }
  }
}
