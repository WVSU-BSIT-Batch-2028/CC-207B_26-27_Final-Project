import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor_prescription.dart';
import '../models/prescription.dart';
import '../models/refill_notice.dart';
import '../models/refill_request.dart';

/// Converts what is stored in Firestore into the app's models, and back.
///
/// These are plain functions with no Firebase calls (only the `Timestamp`
/// type), so they can be unit tested without a Firebase project.

/// A Firestore Timestamp as a calendar date (no time), or null.
DateTime? _dateOf(Object? value) {
  if (value is Timestamp) {
    final d = value.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  return null;
}

/// "capsule" -> "Capsule".
String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// "Take 1 capsule - 2x a day" (same wording the doctor's list shows).
String instructionFor(String form, int timesPerDay) =>
    'Take 1 $form - ${timesPerDay}x a day';

/// Builds the patient-side [Prescription] from one Firestore document.
/// Throws [FormatException] when a required field is missing, so the service
/// can skip a damaged document instead of crashing the whole list.
Prescription prescriptionFromData(String id, Map<String, dynamic> data) {
  final name = data['medicineName'];
  final start = _dateOf(data['startDate']);
  if (name is! String || start == null) {
    throw const FormatException('Prescription is missing required fields.');
  }

  final form = (data['form'] as String?) ?? 'tablet';
  final times = (data['timesPerDay'] as num?)?.toInt() ?? 1;

  return Prescription(
    id: id,
    medicineName: name,
    strength: (data['dosage'] as String?) ?? '',
    form: capitalize(form),
    instruction: instructionFor(form, times),
    durationDays: (data['durationDays'] as num?)?.toInt() ?? 1,
    startDate: start,
    prescribedBy: (data['doctorName'] as String?) ?? 'Your doctor',
    doctorPhone: data['doctorPhone'] as String?,
    prescribedOn: _dateOf(data['createdAt']) ?? start,
    refillDate: _dateOf(data['refillDate']),
    lastRefill: _dateOf(data['lastRefill']),
    notes: data['notes'] as String?,
  );
}

/// Builds the doctor-side [DoctorPrescription] from the same document, so the
/// doctor and the patient always read one record.
DoctorPrescription doctorPrescriptionFromData(
  String id,
  Map<String, dynamic> data,
) {
  final name = data['medicineName'];
  final start = _dateOf(data['startDate']);
  if (name is! String || start == null) {
    throw const FormatException('Prescription is missing required fields.');
  }

  return DoctorPrescription(
    id: id,
    medicineName: name,
    dosage: (data['dosage'] as String?) ?? '',
    form: (data['form'] as String?) ?? 'tablet',
    timesPerDay: (data['timesPerDay'] as num?)?.toInt() ?? 1,
    durationDays: (data['durationDays'] as num?)?.toInt() ?? 1,
    startDate: start,
    refillDate: _dateOf(data['refillDate']),
    notes: data['notes'] as String?,
  );
}

/// The map saved when a doctor adds a prescription. The service adds the
/// server timestamp (`createdAt`) itself.
Map<String, dynamic> doctorPrescriptionToData(
  DoctorPrescription prescription, {
  required String patientId,
  required String doctorId,
  required String doctorName,
}) {
  DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  return {
    'patientId': patientId,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'medicineName': prescription.medicineName,
    'dosage': prescription.dosage,
    'form': prescription.form,
    'timesPerDay': prescription.timesPerDay,
    'durationDays': prescription.durationDays,
    'startDate': Timestamp.fromDate(dayOnly(prescription.startDate)),
    'refillDate': prescription.refillDate == null
        ? null
        : Timestamp.fromDate(dayOnly(prescription.refillDate!)),
    'notes': prescription.notes,
  };
}

/// Builds a [RefillRequest] from one Firestore document.
RefillRequest refillRequestFromData(Map<String, dynamic> data) {
  final statusName = data['status'] as String? ?? 'pending';
  final status = RefillStatus.values.asNameMap()[statusName] ??
      RefillStatus.pending;

  final requested = data['requestedAt'];
  return RefillRequest(
    prescriptionId: (data['prescriptionId'] as String?) ?? '',
    // A pending server timestamp is null for a moment after it is written.
    requestedAt: requested is Timestamp ? requested.toDate() : DateTime.now(),
    status: status,
  );
}

/// Builds the doctor's notification entry from one pending refill request.
/// Requests saved before the patient name was stored show "A patient".
RefillNotice refillNoticeFromData(String id, Map<String, dynamic> data) {
  final requested = data['requestedAt'];
  return RefillNotice(
    id: id,
    prescriptionId: (data['prescriptionId'] as String?) ?? '',
    patientName: (data['patientName'] as String?) ?? 'A patient',
    medicineTitle: (data['medicineTitle'] as String?) ?? 'a medicine',
    requestedAt: requested is Timestamp ? requested.toDate() : DateTime.now(),
    patientUid: data['patientUid'] as String?,
  );
}