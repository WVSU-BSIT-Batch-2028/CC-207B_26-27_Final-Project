/// A refill request that is still waiting for the doctor's answer, as shown
/// in the doctor's Notifications list.
///
/// Plain data: no widgets and no storage code.
class RefillNotice {
  const RefillNotice({
    required this.id,
    required this.prescriptionId,
    required this.patientName,
    required this.medicineTitle,
    required this.requestedAt,
    this.patientUid,
  });

  /// The refill request document id.
  final String id;

  /// Which prescription the patient wants refilled.
  final String prescriptionId;

  /// The patient's name, saved on the request when it was sent.
  final String patientName;

  /// e.g. "Amoxicillin 500mg".
  final String medicineTitle;

  /// When the patient sent the request.
  final DateTime requestedAt;

  /// The patient's account id (useful to open that patient later).
  final String? patientUid;
}