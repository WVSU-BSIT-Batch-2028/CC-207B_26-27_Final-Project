import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/application_details.dart';
import '../../../models/pharmacy_summary.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../widgets/theme/app_colors.dart';

// Human label under the LTO expiry in the pharmacies table
(String label, Color color) ltoExpiryHint(PharmacySummary p, DateTime today) {
  final expiry = DateUtils.dateOnly(p.ltoExpiry);
  final now = DateUtils.dateOnly(today);
  if (expiry.isBefore(now)) return ('Expired', AppColors.danger);
  final days = expiry.difference(now).inDays;
  if (isLtoExpiringSoon(p, today)) return ('Expires in $days days', AppColors.warning);
  return ('Valid', AppColors.primary);
}

String statusLabel(String status) => switch (status) {
      'pending_approval' => 'Pending Approval',
      'active' => 'Active',
      'inactive' => 'Inactive',
      'rejected' => 'Rejected',
      _ => status,
    };

Color statusColor(String status) => switch (status) {
      'pending_approval' => AppColors.warning,
      'active' => AppColors.primary,
      'inactive' => AppColors.neutral,
      'rejected' => AppColors.danger,
      _ => AppColors.neutral,
    };

// Short hours line for the detail drawer (e.g. Mon–Sun, 7:00 AM – 10:00 PM)
String summarizeBranchHours(List<SavedHours> hours) {
  if (hours.isEmpty) return '—';
  final open = hours.where((h) => !h.isClosed).toList();
  if (open.isEmpty) return 'Closed daily';

  String fmt(String? value) {
    if (value == null) return '—';
    final parts = value.split(':');
    final t = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(t);
  }

  final first = open.first;
  final range = '${fmt(first.opensAt)} – ${fmt(first.closesAt)}';
  final allSame = open.every(
    (h) => h.opensAt == first.opensAt && h.closesAt == first.closesAt,
  );
  if (open.length == 7 && allSame) return 'Mon–Sun, $range';

  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return open.map((h) => '${days[h.weekday]} $range').join('; ');
}