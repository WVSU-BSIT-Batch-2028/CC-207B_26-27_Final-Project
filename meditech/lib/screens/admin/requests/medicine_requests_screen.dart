import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/catalogue_medicine.dart';
import '../../../models/medicine_request.dart';
import '../../../providers/catalogue_providers.dart';
import '../../../providers/medicine_request_providers.dart';
import '../../../services/medicine_request_service.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Badge for a request's status
StatusBadge requestStatusBadge(String status) => switch (status) {
      'open' => const StatusBadge('Open', tone: BadgeTone.warning),
      'added' => const StatusBadge('Added', tone: BadgeTone.success),
      _ => const StatusBadge('Dismissed'),
    };

// Admin review of pharmacies' medicine requests (wireframe A-13)
class MedicineRequestsScreen extends ConsumerWidget {
  const MedicineRequestsScreen({super.key});

  static const _tabs = <(String, String?)>[
    ('Open', 'open'),
    ('Added', 'added'),
    ('Dismissed', 'dismissed'),
    ('All', null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(requestStatusProvider);
    final rows = ref.watch(requestListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine requests')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medicines pharmacies asked for that aren\'t in the catalogue yet. '
              'Add the medicine in the catalogue first, then mark the request as added.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),

            // Status tabs
            Wrap(spacing: AppSpacing.sm, children: [
              for (final (label, value) in _tabs)
                ChoiceChip(
                  label: Text(label),
                  selected: status == value,
                  onSelected: (_) => ref.read(requestStatusProvider.notifier).set(value),
                ),
            ]),
            const SizedBox(height: AppSpacing.md),

            // The list
            Expanded(
              child: Card(
                child: AsyncView<List<MedicineRequest>>(
                  value: rows,
                  onRetry: () => ref.invalidate(requestListProvider),
                  isEmpty: (list) => list.isEmpty,
                  emptyMessage: status == 'open' ? 'No open requests. All caught up!' : 'No requests here.',
                  builder: (list) => ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => _RequestRow(request: list[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One request with its actions
class _RequestRow extends ConsumerStatefulWidget {
  const _RequestRow({required this.request});

  final MedicineRequest request;

  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _busy = false;

  MedicineRequest get r => widget.request;

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // Run an action, then reload the list
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(requestListProvider);
      _tell(success);
    } catch (e) {
      _tell(MedicineRequestService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Pick the catalogue medicine, then mark the request as added
  Future<void> _markAdded() async {
    final medicine = await showDialog<CatalogueMedicine>(
      context: context,
      builder: (_) => _PickMedicineDialog(search: r.brandName ?? r.genericName),
    );
    if (medicine == null) return;
    await _run(
      () => ref.read(medicineRequestServiceProvider).markAdded(r.id, medicine.id),
      'Request marked as added. The pharmacy was notified.',
    );
  }

  // Dismiss with a reason
  Future<void> _dismiss() async {
    final reason = await showReasonDialog(
      context,
      title: 'Dismiss ${r.displayId}?',
      description: '${r.pharmacyName} sees this reason.',
      actionLabel: 'Dismiss request',
      hint: 'e.g. Already listed under the brand Keflex.',
    );
    if (reason == null) return;
    await _run(
      () => ref.read(medicineRequestServiceProvider).dismiss(r.id, reason),
      'Request dismissed. The pharmacy was notified.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy · h:mm a');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // What was asked for, and by whom
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(r.genericName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(width: AppSpacing.sm),
              requestStatusBadge(r.status),
            ]),
            if (r.details.isNotEmpty) Text(r.details),
            if (r.registrationNumber != null)
              Text('Registration: ${r.registrationNumber}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.xs),
            Text('${r.pharmacyName} · ${r.branchName} · ${r.requestedBy}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Text('${r.displayId} · ${date.format(r.createdAt)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (r.notes != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('"${r.notes}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (r.dismissReason != null)
              Text('Dismissed: ${r.dismissReason}', style: const TextStyle(color: AppColors.danger)),
          ]),
        ),

        // Actions, only while open
        if (r.status == 'open')
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            FilledButton(
              onPressed: _busy ? null : _markAdded,
              child: const Text('Mark as added'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _dismiss,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Dismiss'),
            ),
          ]),
      ]),
    );
  }
}

// Search the catalogue and pick the medicine this request became
class _PickMedicineDialog extends ConsumerStatefulWidget {
  const _PickMedicineDialog({required this.search});

  final String search;

  @override
  ConsumerState<_PickMedicineDialog> createState() => _PickMedicineDialogState();
}

class _PickMedicineDialogState extends ConsumerState<_PickMedicineDialog> {
  late final _search = TextEditingController(text: widget.search);
  late Future<List<CatalogueMedicine>> _results = _find();

  // Look up catalogue medicines matching the search
  Future<List<CatalogueMedicine>> _find() =>
      ref.read(catalogueServiceProvider).list(search: _search.text.trim());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Which catalogue medicine is it?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() => _results = _find()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                  hintText: 'Search the catalogue'),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: FutureBuilder<List<CatalogueMedicine>>(
                future: _results,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return const StateMessage(
                      icon: Icons.search_off,
                      message: 'Not in the catalogue yet. Add it in the catalogue first, then come back.',
                    );
                  }
                  return ListView(children: [
                    for (final m in list)
                      ListTile(
                        title: Text('${m.brandName} · ${m.strength}'),
                        subtitle: Text('${m.genericName} · ${m.dosageForm} · ${m.displayId}'),
                        trailing: StatusBadge(
                          m.status == 'active' ? 'Active' : m.status == 'draft' ? 'Pending review' : 'Inactive',
                          tone: m.status == 'active' ? BadgeTone.success : BadgeTone.neutral,
                        ),
                        onTap: () => Navigator.pop(context, m),
                      ),
                  ]);
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
          ]),
        ),
      ),
    );
  }
}