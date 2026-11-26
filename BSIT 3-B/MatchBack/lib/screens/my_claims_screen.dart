import 'package:flutter/material.dart';

import '../models/claim_request.dart';
import '../services/auth_service.dart';
import '../models/notification_record.dart';
import '../services/claim_storage.dart';
import '../services/notification_storage.dart';
import '../utils/notification_text.dart';
import '../utils/date_format.dart';
import '../utils/status_labels.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  final _claimStorage = ClaimStorage();
  final _notificationStorage = NotificationStorage();

  // Staff contact attempts, grouped by claim id.
  Map<String, List<NotificationRecord>> _notes = {};
  late Future<List<ClaimRequest>> _claimsFuture;

  @override
  void initState() {
    super.initState();
    _claimsFuture = _loadClaims();
  }

  Future<List<ClaimRequest>> _loadClaims() {
    final uid = AuthService.current?.uid;
    if (uid == null || uid.isEmpty) {
      return Future.value(<ClaimRequest>[]);
    }
    _loadNotes();
    return _claimStorage.loadForCurrentStudent();
  }

  Future<void> refreshClaims() async {
    setState(() {
      _claimsFuture = _loadClaims();
    });

    await _claimsFuture;
  }

  Color statusColor(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'ready':
        return Colors.teal;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      case 'returned':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  /// A short sentence telling the student what happens next.
  String statusMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Staff are reviewing your claim.';
      case 'approved':
        return 'Your claim was approved. Staff will update this page when '
            'the item is ready for collection.';
      case 'ready':
        return 'Your item is ready for collection at the office.';
      case 'returned':
        return 'This item was handed back to you.';
      case 'rejected':
        return 'This claim was not approved.';
      default:
        return '';
    }
  }

  Future<void> _loadNotes() async {
    try {
      final records = await _notificationStorage.loadForCurrentStudent();
      if (!mounted) return;

      final grouped = <String, List<NotificationRecord>>{};
      for (final record in records) {
        grouped.putIfAbsent(record.claimId, () => []).add(record);
      }

      setState(() {
        _notes = grouped;
      });
    } catch (_) {
      // Updates are extra information, so the claims still show without them.
    }
  }

  /// Updates from staff, such as "Staff contacted you by email".
  List<Widget> updates(ClaimRequest claim) {
    final notes = _notes[claim.id] ?? [];

    return [
      for (final note in notes)
        if (note.sentAt != null)
          Text(
            '${formatPhilippineTime(note.sentAt!)}: '
            '${studentNotificationText(event: note.event, method: note.method, outcome: note.outcome)}',
          ),
    ];
  }

  /// One line for each step that has happened, with its recorded time.
  List<Widget> timeline(ClaimRequest claim) {
    final steps = <MapEntry<String, DateTime?>>[
      MapEntry('Approved', claim.approvedAt),
      MapEntry('Marked ready for collection', claim.readyAt),
      MapEntry('Returned to you', claim.returnedAt),
      MapEntry('Rejected', claim.rejectedAt),
    ];

    return [
      for (final step in steps)
        if (step.value != null)
          Text('${step.key}: ${formatPhilippineTime(step.value!)}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Claim Status')),
      body: FutureBuilder<List<ClaimRequest>>(
        future: _claimsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load your claims.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: refreshClaims,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final claims = snapshot.data ?? [];

          if (claims.isEmpty) {
            return const Center(
              child: Text('You have not submitted any claims yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: refreshClaims,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: claims.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final claim = claims[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: statusColor(
                        context,
                        claim.status,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.assignment_turned_in_outlined,
                        color: statusColor(context, claim.status),
                      ),
                    ),
                    title: Text(claim.foundItemName),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Use the server's stored time when it exists, and
                          // fall back to the device date for very old claims.
                          Text(
                            claim.createdAt != null
                                ? 'Submitted: ${formatPhilippineTime(claim.createdAt!)}'
                                : 'Submitted: ${claim.submittedAt.substring(0, 10)}',
                          ),
                          ...timeline(claim),
                          ...updates(claim),
                          const SizedBox(height: 8),
                          Text(
                            statusMessage(claim.status),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    trailing: Chip(
                      label: Text(claimStatusLabel(claim.status)),
                      backgroundColor: statusColor(
                        context,
                        claim.status,
                      ).withValues(alpha: 0.15),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
