import 'package:flutter/material.dart';

import '../models/claim_request.dart';
import '../services/claim_storage.dart';
import '../utils/date_format.dart';
import '../utils/status_labels.dart';
import '../widgets/contact_reveal.dart';
import '../widgets/notify_panel.dart';
import 'staff_lost_reports_screen.dart';

class StaffClaimsScreen extends StatefulWidget {
  const StaffClaimsScreen({super.key});

  @override
  State<StaffClaimsScreen> createState() => _StaffClaimsScreenState();
}

class _StaffClaimsScreenState extends State<StaffClaimsScreen> {
  final _claimStorage = ClaimStorage();

  late Future<List<ClaimRequest>> _claimsFuture;
  String? _updatingClaimId;
  String _filter = 'all';

  // The filter chips shown above the list.
  static const _filters = {
    'all': 'All',
    'pending': 'Pending Review',
    'collection': 'Awaiting Collection',
    'closed': 'Closed',
  };

  @override
  void initState() {
    super.initState();
    _claimsFuture = _claimStorage.loadAll();
  }

  void reloadClaims() {
    setState(() {
      _claimsFuture = _claimStorage.loadAll();
    });
  }

  /// "Awaiting collection" means approved, or ready at the office, but not
  /// yet handed over.
  bool _matchesFilter(ClaimRequest claim) {
    switch (_filter) {
      case 'pending':
        return claim.status == 'pending';
      case 'collection':
        return claim.status == 'approved' || claim.status == 'ready';
      case 'closed':
        return claim.status == 'returned' || claim.status == 'rejected';
      default:
        return true;
    }
  }

  /// Turns the workflow's error codes into messages staff can understand.
  String _errorMessage(Object error) {
    // On the web, an error thrown inside a Firestore transaction arrives
    // wrapped, so it is matched by its text instead of its type.
    final text = error.toString();

    if (text.contains('item-unavailable')) {
      return 'This item already has an approved claim, or it is no longer '
          'available. Reject this claim, or check the item.';
    }
    if (text.contains('invalid-step')) {
      return 'This claim was already updated. The list has been refreshed.';
    }
    return 'Could not update the claim. Please try again.';
  }

  Future<void> updateClaimStatus(ClaimRequest claim, String newStatus) async {
    setState(() {
      _updatingClaimId = claim.id;
    });

    try {
      await _claimStorage.advance(claim, newStatus);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claim marked as ${claimStatusLabel(newStatus)}.'),
        ),
      );
    } catch (error) {
      // Print the real reason so it can be read in the browser console.
      debugPrint('Claim update failed: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _updatingClaimId = null;
        });
        // Reload either way, so the list always shows the server's state.
        reloadClaims();
      }
    }
  }

  /// The return time is official, so staff must confirm the handover first.
  Future<void> confirmHandover(ClaimRequest claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm handover'),
        content: Text(
          'Confirm that "${claim.foundItemName}" was physically handed to '
          '${claim.claimantName}. This records the official return time and '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await updateClaimStatus(claim, 'returned');
    }
  }

  /// One line for each step that has happened, with its recorded time.
  List<Widget> _history(ClaimRequest claim) {
    final steps = <MapEntry<String, DateTime?>>[
      MapEntry('Submitted', claim.createdAt),
      MapEntry('Approved', claim.approvedAt),
      MapEntry('Rejected', claim.rejectedAt),
      MapEntry('Marked ready for collection', claim.readyAt),
      MapEntry('Returned to owner', claim.returnedAt),
    ];

    return [
      for (final step in steps)
        if (step.value != null)
          Text('${step.key}: ${formatPhilippineTime(step.value!)}'),
    ];
  }

  /// The buttons that fit the claim's current status.
  Widget _actions(ClaimRequest claim) {
    switch (claim.status) {
      case 'pending':
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => updateClaimStatus(claim, 'rejected'),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => updateClaimStatus(claim, 'approved'),
              child: const Text('Approve Claim'),
            ),
          ],
        );
      case 'approved':
        return FilledButton.icon(
          onPressed: () => updateClaimStatus(claim, 'ready'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Mark Ready for Collection'),
        );
      case 'ready':
        return FilledButton.icon(
          onPressed: () => confirmHandover(claim),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Record Handover (Returned)'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Claim Review'),
        actions: [
          IconButton(
            tooltip: 'Lost-report private details',
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StaffLostReportsScreen(),
                ),
              );
            },
          ),
        ],
      ),
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
                  const Text('Could not load the claims.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: reloadClaims,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final allClaims = snapshot.data ?? [];

          if (allClaims.isEmpty) {
            return const Center(
              child: Text('No claim requests have been submitted yet.'),
            );
          }

          final claims = allClaims.where(_matchesFilter).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _filters.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        onSelected: (_) {
                          setState(() {
                            _filter = entry.key;
                          });
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: claims.isEmpty
                    ? const Center(child: Text('No claims match this filter.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: claims.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final claim = claims[index];
                          final isUpdating = _updatingClaimId == claim.id;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.verified_user_outlined),
                                    ),
                                    title: Text(claim.foundItemName),
                                    subtitle: Text(
                                      'Claimant: ${claim.claimantName}',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        claimStatusLabel(claim.status),
                                      ),
                                    ),
                                  ),
                                  ..._history(claim),
                                  const SizedBox(height: 8),
                                  Text('Reason: ${claim.reason}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Private detail for staff verification: '
                                    '${claim.privateDetail}',
                                  ),
                                  const SizedBox(height: 16),
                                  ContactReveal(
                                    key: ValueKey('claim_contact_${claim.id}'),
                                    kind: 'claim',
                                    refId: claim.id,
                                  ),
                                  const SizedBox(height: 16),
                                  if (claim.status == 'approved' ||
                                      claim.status == 'ready') ...[
                                    NotifyPanel(
                                      key: ValueKey('notify_${claim.id}'),
                                      claim: claim,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (isUpdating)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  else
                                    _actions(claim),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
