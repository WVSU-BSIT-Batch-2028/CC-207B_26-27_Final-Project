import '../utils/date_format.dart';

class ClaimRequest {
  const ClaimRequest({
    required this.id,
    required this.foundItemId,
    required this.foundItemName,
    required this.claimantName,
    required this.reason,
    required this.privateDetail,
    required this.status,
    required this.submittedAt,
    this.studentId = '',
    this.ownerUid = '',
    this.createdAt,
    this.approvedAt,
    this.readyAt,
    this.returnedAt,
    this.rejectedAt,
  });

  final String id;
  final String foundItemId;
  final String foundItemName;
  final String claimantName;
  final String reason;
  final String privateDetail;
  final String status;
  final String submittedAt;
  final String studentId;
  final String ownerUid;

  /// Server times. Each is null until staff take that step.
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? readyAt;
  final DateTime? returnedAt;
  final DateTime? rejectedAt;

  ClaimRequest copyWith({String? status}) {
    return ClaimRequest(
      id: id,
      foundItemId: foundItemId,
      foundItemName: foundItemName,
      claimantName: claimantName,
      reason: reason,
      privateDetail: privateDetail,
      status: status ?? this.status,
      submittedAt: submittedAt,
      studentId: studentId,
      ownerUid: ownerUid,
      createdAt: createdAt,
      approvedAt: approvedAt,
      readyAt: readyAt,
      returnedAt: returnedAt,
      rejectedAt: rejectedAt,
    );
  }

  /// Only what a student sends. The workflow times are set by the server
  /// when staff take each step, never by this app.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foundItemId': foundItemId,
      'foundItemName': foundItemName,
      'claimantName': claimantName,
      'reason': reason,
      'privateDetail': privateDetail,
      'status': status,
      'submittedAt': submittedAt,
      'studentId': studentId,
      'ownerUid': ownerUid,
    };
  }

  factory ClaimRequest.fromJson(Map<String, dynamic> json) {
    return ClaimRequest(
      id: json['id'] as String,
      foundItemId: json['foundItemId'] as String,
      foundItemName: json['foundItemName'] as String,
      claimantName: json['claimantName'] as String,
      reason: json['reason'] as String,
      privateDetail: json['privateDetail'] as String,
      status: json['status'] as String,
      submittedAt: json['submittedAt'] as String,
      studentId: (json['studentId'] as String?) ?? '',
      ownerUid: (json['ownerUid'] as String?) ?? '',
      createdAt: parseTime(json['createdAt']),
      approvedAt: parseTime(json['approvedAt']),
      readyAt: parseTime(json['readyAt']),
      returnedAt: parseTime(json['returnedAt']),
      rejectedAt: parseTime(json['rejectedAt']),
    );
  }
}
