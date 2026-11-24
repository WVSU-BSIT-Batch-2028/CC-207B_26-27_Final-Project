import '../../../widgets/common/status_badge.dart';

// Labels for [AuditRecord.eventType] values from the database enum.
(String, BadgeTone) auditEventTypeBadge(String eventType) => switch (eventType) {
      'sign_in' => ('Sign-in', BadgeTone.neutral),
      'failed_sign_in' => ('Failed sign-in', BadgeTone.danger),
      'account_security' => ('Account security', BadgeTone.warning),
      'pharmacy_application' => ('Pharmacy application', BadgeTone.info),
      'admin_action' => ('Admin action', BadgeTone.neutral),
      'data_export' => ('Data export', BadgeTone.neutral),
      _ => (eventType.replaceAll('_', ' '), BadgeTone.neutral),
    };