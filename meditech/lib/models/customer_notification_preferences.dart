class CustomerNotificationPreferences {
  const CustomerNotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;

  String get summary {
    final parts = <String>[];
    if (pushEnabled) parts.add('Push');
    if (emailEnabled) parts.add('Email');
    if (smsEnabled) parts.add('SMS');
    if (parts.isEmpty) return 'All off';
    return parts.join(' · ');
  }

  CustomerNotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) {
    return CustomerNotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }

  factory CustomerNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return CustomerNotificationPreferences(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? true,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'sms_enabled': smsEnabled,
    };
  }
}