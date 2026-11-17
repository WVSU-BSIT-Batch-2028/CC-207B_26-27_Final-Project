import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/application_details.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'pharmacies_screen.dart';

// Right-side panel showing one application (wireframes A-05, A-07)
class ApplicationDrawer extends ConsumerWidget {
  const ApplicationDrawer({super.key, required this.branchId, required this.onClose});

  final String branchId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(applicationDetailsProvider(branchId));

    return Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: AsyncView<ApplicationDetails?>(
        value: details,
        onRetry: () => ref.invalidate(applicationDetailsProvider(branchId)),
        isEmpty: (d) => d == null,
        emptyMessage: 'This application could not be found.',
        builder: (d) => _DrawerContent(details: d!, onClose: onClose),
      ),
    );
  }
}

class _DrawerContent extends ConsumerWidget {
  const _DrawerContent({required this.details, required this.onClose});

  final ApplicationDetails details;
  final VoidCallback onClose;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // "08:00:00" → "8:00 AM"
  String _time(String? value) {
    if (value == null) return '-';
    final parts = value.split(':');
    final t = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(t);
  }

  // Open a document: photos in a viewer, PDFs in the browser
  Future<void> _open(BuildContext context, WidgetRef ref, DocumentInfo doc) async {
    try {
      final link = await ref.read(adminPharmacyServiceProvider).documentLink(doc.path);
      if (!context.mounted) return;
      if (doc.isImage) {
        await showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(child: Image.network(link, fit: BoxFit.contain)),
          ),
        );
      } else {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this document. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = details;
    final date = DateFormat('MMM d, yyyy');
    final expired = d.ltoExpiry.isBefore(DateUtils.dateOnly(DateTime.now()));

    // A titled group of label-value rows
    Widget section(String title, List<(String, String)> rows) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120,
                      child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
                  Expanded(child: Text(value)),
                ]),
              ),
          ]),
        );

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.pharmacyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${d.branchName} · ${d.displayId}',
                    style: const TextStyle(color: AppColors.textMuted)),
              ]),
            ),
            branchStatusBadge(d.status),
            IconButton(tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(),

        // Details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (d.possibleDuplicate)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Text(
                    'Possible duplicate: a pharmacy with a similar name is registered nearby. '
                    'Check before approving.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              if (d.rejectionReason != null)
                section('Rejection reason', [('Reason', d.rejectionReason!)]),
              section('Pharmacy', [
                ('Address', d.address),
                ('Contact', d.contactNumber),
                ('Email', d.email),
                ('Location', '${d.latitude.toStringAsFixed(6)}, ${d.longitude.toStringAsFixed(6)}'),
                ('Submitted', date.format(d.submittedAt)),
              ]),
              section('FDA License to Operate', [
                ('LTO number', d.ltoNumber),
                ('Expires', expired ? '${date.format(d.ltoExpiry)} (expired)' : date.format(d.ltoExpiry)),
              ]),
              section('Opening hours', [
                for (final i in [1, 2, 3, 4, 5, 6, 0])
                  for (final h in d.hours.where((h) => h.weekday == i))
                    (_days[i], h.isClosed ? 'Closed' : '${_time(h.opensAt)} – ${_time(h.closesAt)}'),
              ]),
              if (d.owner != null)
                section('Owner account', [
                  ('Name', d.owner!.name),
                  ('Mobile', d.owner!.mobile ?? '-'),
                  ('Email', d.owner!.email ?? '-'),
                  ('Username', d.owner!.username ?? '-'),
                ]),

              // Documents, opened with short-lived links
              const Text('DOCUMENTS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: AppSpacing.sm),
              if (d.documents.isEmpty)
                const Text('No documents uploaded.', style: TextStyle(color: AppColors.textMuted)),
              for (final doc in d.documents)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Icon(doc.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
                    title: Text(switch (doc.kind) {
                      'lto' => 'License to Operate',
                      'storefront' => 'Storefront photo',
                      _ => 'Renewed LTO',
                    }),
                    subtitle: Text('${(doc.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _open(context, ref, doc),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // FDA check and approval come in the next task
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.neutralLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text('FDA verification and Approve / Reject come next.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}