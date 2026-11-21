// One item on the admin's to-do list
class TodoItem {
  const TodoItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.detail,
    this.since,
  });

  final String kind; // application, request, medicine, lto_expiring
  final String id;
  final String title;
  final String detail;
  final DateTime? since; // when it was sent, or when an LTO expires

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
        since: json['since'] == null ? null : DateTime.parse(json['since'] as String).toLocal(),
      );
}

// Everything on the admin overview
class AdminOverview {
  const AdminOverview({
    required this.pendingApplications,
    required this.activePharmacies,
    required this.inactivePharmacies,
    required this.medicinesPendingReview,
    required this.activeMedicines,
    required this.openRequests,
    required this.ltoExpiringSoon,
    required this.todo,
  });

  final int pendingApplications;
  final int activePharmacies;
  final int inactivePharmacies;
  final int medicinesPendingReview;
  final int activeMedicines;
  final int openRequests;
  final int ltoExpiringSoon;
  final List<TodoItem> todo;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num? ?? 0).toInt();
    return AdminOverview(
      pendingApplications: count('pending_applications'),
      activePharmacies: count('active_pharmacies'),
      inactivePharmacies: count('inactive_pharmacies'),
      medicinesPendingReview: count('medicines_pending_review'),
      activeMedicines: count('active_medicines'),
      openRequests: count('open_requests'),
      ltoExpiringSoon: count('lto_expiring_soon'),
      todo: (json['todo'] as List? ?? const [])
          .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}