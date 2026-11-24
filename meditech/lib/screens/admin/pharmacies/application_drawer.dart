import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/application_details.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../services/admin_pharmacy_service.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'branch_status_panel.dart';
import 'pharmacy_admin_format.dart';
import 'pharmacies_screen.dart';
import 'application_review_card.dart';

// Right-side panel for one pharmacy (wireframes A-05, A-07, A-09)
class ApplicationDrawer extends ConsumerWidget {
  const ApplicationDrawer({
    super.key,
    required this.branchId,
    required this.onClose,
  });

  final String branchId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(applicationDetailsProvider(branchId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
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

class _DrawerContent extends ConsumerStatefulWidget {
  const _DrawerContent({required this.details, required this.onClose});

  final ApplicationDetails details;
  final VoidCallback onClose;

  @override
  ConsumerState<_DrawerContent> createState() => _DrawerContentState();
}

class _DrawerContentState extends ConsumerState<_DrawerContent> {
  bool _sendingReminder = false;

  ApplicationDetails get d => widget.details;

  Future<void> _openDoc(DocumentInfo doc) async {
    try {
      final link = await ref.read(adminPharmacyServiceProvider).documentLink(doc.path);
      if (!mounted) return;
      if (doc.isImage) {
        final title = switch (doc.kind) {
          'lto' => 'FDA License to Operate',
          'storefront' => 'Storefront photo',
          _ => 'Uploaded document',
        };
        await showTabletImageViewer(context: context, imageUrl: link, title: title);
      } else {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this document. Please try again.')),
        );
      }
    }
  }

  Future<void> _sendReminder() async {
    setState(() => _sendingReminder = true);
    try {
      await ref.read(adminPharmacyServiceProvider).sendLtoReminder(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent to the owner.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AdminPharmacyService.friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  Widget _labeledRows(List<(String, String)> rows) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(rows[i].$2, style: const TextStyle(fontSize: 14, height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

  Widget _infoSection(String title, List<(String, String)> rows) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _labeledRows(rows),
          ],
        ),
      );

  Widget _fdaLicenseCard({
    required String ltoNumber,
    required DateTime ltoExpiry,
    required bool expired,
    required int daysLeft,
    required DateFormat date,
    DateTime? lastChecked,
  }) {
    final expiresValue = expired
        ? '${date.format(ltoExpiry)} (expired)'
        : daysLeft <= 60
            ? 'Expires in $daysLeft days'
            : date.format(ltoExpiry);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FDA License to Operate',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.md),
          _labeledRows([
            ('LTO number', ltoNumber),
            ('Expires', expiresValue),
            if (lastChecked != null) ('Last verified', date.format(lastChecked)),
          ]),
        ],
      ),
    );
  }

  bool _showLtoReminder(DateTime today) {
    if (d.status != 'active') return false;
    final expiry = DateUtils.dateOnly(d.ltoExpiry);
    final now = DateUtils.dateOnly(today);
    if (expiry.isBefore(now)) return true;
    return expiry.difference(now).inDays <= 30;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final date = DateFormat('MMM d, yyyy');
    final checks = ref.watch(branchChecksProvider(d.id));
    final lastCheck = checks.asData?.value.isNotEmpty == true ? checks.asData!.value.first : null;
    final expired = d.ltoExpiry.isBefore(DateUtils.dateOnly(today));
    final daysLeft = DateUtils.dateOnly(d.ltoExpiry).difference(DateUtils.dateOnly(today)).inDays;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.pharmacyName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${d.displayId} · ${d.branchName}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    branchStatusBadge(d.status),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              if (_showLtoReminder(today)) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final stacked = box.maxWidth < 300;
                      final textBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expired
                                ? 'LTO expired on ${date.format(d.ltoExpiry)}.'
                                : 'LTO expires in $daysLeft days (${date.format(d.ltoExpiry)}).',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Send the owner a reminder to renew it.',
                            style: TextStyle(color: AppColors.text, height: 1.35),
                          ),
                        ],
                      );
                      final reminderBtn = OutlinedButton(
                        onPressed: _sendingReminder ? null : _sendReminder,
                        style: TabletControls.actionOutlined(
                          foreground: AppColors.text,
                          border: AppColors.border,
                          background: Colors.white,
                        ).copyWith(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: _sendingReminder
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send reminder'),
                      );
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textBlock,
                            const SizedBox(height: AppSpacing.md),
                            Align(alignment: Alignment.centerRight, child: reminderBtn),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: textBlock),
                          const SizedBox(width: AppSpacing.sm),
                          reminderBtn,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (d.status == 'active' || d.status == 'inactive') ...[
                BranchStatusPanel(details: d, showIntro: false),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (d.status == 'pending_approval')
                ApplicationReviewCard(details: d, onOpenDocument: _openDoc)
              else
                _infoSection('Branch information', [
                  ('Address', d.address),
                  ('Contact', d.contactNumber),
                  ('Email', d.email),
                  ('Hours', summarizeBranchHours(d.hours)),
                  ('Pharmacist', d.owner?.name ?? '—'),
                ]),

              if (d.status != 'pending_approval')
                _fdaLicenseCard(
                  ltoNumber: d.ltoNumber,
                  ltoExpiry: d.ltoExpiry,
                  expired: expired,
                  daysLeft: daysLeft,
                  date: date,
                  lastChecked: lastCheck?.checkedAt,
                ),
              if (d.status != 'pending_approval') const SizedBox(height: AppSpacing.lg),

              if (d.rejectionReason != null)
                _infoSection('Rejection reason', [('Reason', d.rejectionReason!)]),
            ],
          ),
        ),
      ],
    );
  }
}