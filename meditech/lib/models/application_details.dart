// Opening hours for one day, as saved
class SavedHours {
  const SavedHours({required this.weekday, this.opensAt, this.closesAt, required this.isClosed});

  final int weekday; // 0 = Sunday
  final String? opensAt; // like "08:00:00"
  final String? closesAt;
  final bool isClosed;

  factory SavedHours.fromJson(Map<String, dynamic> json) => SavedHours(
        weekday: json['weekday'] as int,
        opensAt: json['opens_at'] as String?,
        closesAt: json['closes_at'] as String?,
        isClosed: json['is_closed'] as bool? ?? false,
      );
}

// The applicant owner
class OwnerInfo {
  const OwnerInfo({required this.name, this.mobile, this.email, this.username, this.displayId});

  final String name;
  final String? mobile;
  final String? email;
  final String? username;
  final String? displayId;

  factory OwnerInfo.fromJson(Map<String, dynamic> json) => OwnerInfo(
        name: json['name'] as String,
        mobile: json['mobile'] as String?,
        email: json['email'] as String?,
        username: json['username'] as String?,
        displayId: json['display_id'] as String?,
      );
}

// An uploaded file (LTO or storefront)
class DocumentInfo {
  const DocumentInfo({required this.kind, required this.path, required this.mimeType, required this.sizeBytes});

  final String kind; // lto, storefront, lto_renewal
  final String path;
  final String mimeType;
  final int sizeBytes;

  bool get isImage => mimeType.startsWith('image/');

  factory DocumentInfo.fromJson(Map<String, dynamic> json) => DocumentInfo(
        kind: json['kind'] as String,
        path: json['path'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int,
      );
}

// Everything the admin sees when reviewing one application
class ApplicationDetails {
  const ApplicationDetails({
    required this.id,
    required this.displayId,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.contactNumber,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.ltoNumber,
    required this.ltoExpiry,
    required this.status,
    required this.submittedAt,
    this.rejectionReason,
    required this.possibleDuplicate,
    required this.hours,
    this.owner,
    required this.documents,
  });

  final String id;
  final String displayId;
  final String pharmacyName;
  final String branchName;
  final String address;
  final String contactNumber;
  final String email;
  final double latitude;
  final double longitude;
  final String ltoNumber;
  final DateTime ltoExpiry;
  final String status;
  final DateTime submittedAt;
  final String? rejectionReason;
  final bool possibleDuplicate;
  final List<SavedHours> hours;
  final OwnerInfo? owner;
  final List<DocumentInfo> documents;

  factory ApplicationDetails.fromJson(Map<String, dynamic> json) => ApplicationDetails(
        id: json['id'] as String,
        displayId: json['display_id'] as String,
        pharmacyName: json['pharmacy_name'] as String,
        branchName: json['branch_name'] as String,
        address: json['address'] as String,
        contactNumber: json['contact_number'] as String,
        email: json['email'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        ltoNumber: json['lto_number'] as String,
        ltoExpiry: DateTime.parse(json['lto_expiry'] as String),
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
        rejectionReason: json['rejection_reason'] as String?,
        possibleDuplicate: json['possible_duplicate'] as bool? ?? false,
        hours: (json['hours'] as List).map((h) => SavedHours.fromJson(h as Map<String, dynamic>)).toList(),
        owner: json['owner'] == null ? null : OwnerInfo.fromJson(json['owner'] as Map<String, dynamic>),
        documents: (json['documents'] as List)
            .map((d) => DocumentInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}