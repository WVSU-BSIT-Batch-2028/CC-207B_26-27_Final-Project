/// Where a refill request is in its life: waiting, accepted or refused.
enum RefillStatus { pending, approved, declined }

/// Text shown to the user for each status (the colour/icon live in
/// `RefillStatusChip`, so the model stays free of UI code).
extension RefillStatusX on RefillStatus {
  String get label {
    switch (this) {
      case RefillStatus.pending:
        return 'Refill pending';
      case RefillStatus.approved:
        return 'Refill approved';
      case RefillStatus.declined:
        return 'Refill declined';
    }
  }
}

/// A patient's request for more of a prescribed medicine.
///
/// The patient submits it (status starts as pending). The doctor side, built
/// by another member, will approve or decline it.
class RefillRequest {
  const RefillRequest({
    required this.prescriptionId,
    required this.requestedAt,
    this.status = RefillStatus.pending,
  });

  /// Which prescription the refill is for (matches `Prescription.id`).
  final String prescriptionId;

  /// When the patient sent the request.
  final DateTime requestedAt;

  /// Current status. New requests are always pending.
  final RefillStatus status;
}
