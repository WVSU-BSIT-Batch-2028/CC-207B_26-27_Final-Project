import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_notification_preferences.dart';
import '../models/customer_profile.dart';
import '../models/customer_profile_overview.dart';
import '../models/customer_saved_address.dart';

const _avatarBucket = 'customer-avatars';

abstract class ProfileService {
  Future<CustomerProfile?> loadMine();
  Future<CustomerProfileOverview?> loadOverview();
  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String mobile,
    required DateTime birthdate,
  });
  Future<String?> uploadAvatar({
    required String fileName,
    required Uint8List bytes,
  });
  Future<List<CustomerSavedAddress>> loadSavedAddresses();
  Future<void> saveAddress(CustomerSavedAddress address, {required bool isNew});
  Future<void> deleteAddress(String id);
  Future<CustomerNotificationPreferences> loadNotificationPreferences();
  Future<void> saveNotificationPreferences(CustomerNotificationPreferences prefs);
}

class SupabaseProfileService implements ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  static const _profileColumns =
      'first_name, middle_name, last_name, mobile, email, birthdate, consent_version';
  static const _profileColumnsWithAvatar = '$_profileColumns, avatar_path';

  @override
  Future<CustomerProfile?> loadMine() async {
    final id = _userId;
    if (id == null) return null;

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('customer_profiles')
          .select(_profileColumnsWithAvatar)
          .eq('account_id', id)
          .maybeSingle();
    } on PostgrestException {
      row = await _client
          .from('customer_profiles')
          .select(_profileColumns)
          .eq('account_id', id)
          .maybeSingle();
    }
    if (row == null) return null;
    return CustomerProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerProfileOverview?> loadOverview() async {
    final id = _userId;
    if (id == null) return null;

    final profile = await loadMine();
    if (profile == null) return null;

    var addressCount = 0;
    try {
      final addressRows = await _client
          .from('customer_saved_addresses')
          .select('id')
          .eq('account_id', id);
      addressCount = addressRows.length;
    } on PostgrestException {
      addressCount = 0;
    }

    var prefs = const CustomerNotificationPreferences();
    try {
      final prefsRow = await _client
          .from('customer_notification_preferences')
          .select('push_enabled, email_enabled, sms_enabled')
          .eq('account_id', id)
          .maybeSingle();

      prefs = prefsRow == null
          ? const CustomerNotificationPreferences()
          : CustomerNotificationPreferences.fromJson(
              Map<String, dynamic>.from(prefsRow),
            );

      if (prefsRow == null) {
        try {
          await _client.from('customer_notification_preferences').insert({
            'account_id': id,
            ...prefs.toJson(),
          });
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
        }
      }
    } on PostgrestException {
      prefs = const CustomerNotificationPreferences();
    }

    String? avatarUrl;
    final path = profile.avatarPath;
    if (path != null && path.isNotEmpty) {
      avatarUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    }

    final passwordUpdatedAt =
        _parseAuthTimestamp(_client.auth.currentUser?.updatedAt);

    return CustomerProfileOverview(
      profile: profile,
      savedAddressCount: addressCount,
      notificationPreferences: prefs,
      avatarPublicUrl: avatarUrl,
      passwordLastUpdatedAt: passwordUpdatedAt,
    );
  }

  @override
  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String mobile,
    required DateTime birthdate,
  }) async {
    final id = _userId;
    if (id == null) {
      throw const AuthException('Sign in to update your profile.');
    }

    final middle = middleName?.trim();
    await _client.from('customer_profiles').update({
      'first_name': firstName.trim(),
      'middle_name': middle == null || middle.isEmpty ? null : middle,
      'last_name': lastName.trim(),
      'mobile': mobile.trim(),
      'birthdate': birthdate.toIso8601String().split('T').first,
    }).eq('account_id', id);
  }

  @override
  Future<String?> uploadAvatar({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final id = _userId;
    if (id == null) {
      throw const AuthException('Sign in to upload a photo.');
    }
    if (bytes.isEmpty) return null;

    final ext = _extensionForName(fileName);
    final path = '$id/avatar.$ext';

    await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeFor(ext),
          ),
        );

    await _client
        .from('customer_profiles')
        .update({'avatar_path': path})
        .eq('account_id', id);

    return _client.storage.from(_avatarBucket).getPublicUrl(path);
  }

  @override
  Future<List<CustomerSavedAddress>> loadSavedAddresses() async {
    final id = _userId;
    if (id == null) return [];

    final rows = await _client
        .from('customer_saved_addresses')
        .select()
        .eq('account_id', id)
        .order('is_default', ascending: false)
        .order('created_at');

    return rows
        .map((row) => CustomerSavedAddress.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> saveAddress(CustomerSavedAddress address, {required bool isNew}) async {
    final id = _userId;
    if (id == null) {
      throw const AuthException('Sign in to save an address.');
    }

    if (address.isDefault) {
      await _client
          .from('customer_saved_addresses')
          .update({'is_default': false})
          .eq('account_id', id);
    }

    final payload = {
      ...address.toInsertJson(),
      'account_id': id,
    };

    if (isNew) {
      await _client.from('customer_saved_addresses').insert(payload);
    } else {
      await _client
          .from('customer_saved_addresses')
          .update(address.toUpdateJson())
          .eq('id', address.id)
          .eq('account_id', id);
    }
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    final id = _userId;
    if (id == null) {
      throw const AuthException('Sign in to remove an address.');
    }
    await _client
        .from('customer_saved_addresses')
        .delete()
        .eq('id', addressId)
        .eq('account_id', id);
  }

  @override
  Future<CustomerNotificationPreferences> loadNotificationPreferences() async {
    final id = _userId;
    if (id == null) return const CustomerNotificationPreferences();

    final row = await _client
        .from('customer_notification_preferences')
        .select('push_enabled, email_enabled, sms_enabled')
        .eq('account_id', id)
        .maybeSingle();

    if (row == null) {
      const defaults = CustomerNotificationPreferences();
      await _client.from('customer_notification_preferences').insert({
        'account_id': id,
        ...defaults.toJson(),
      });
      return defaults;
    }
    return CustomerNotificationPreferences.fromJson(row);
  }

  @override
  Future<void> saveNotificationPreferences(
    CustomerNotificationPreferences prefs,
  ) async {
    final id = _userId;
    if (id == null) {
      throw const AuthException('Sign in to save preferences.');
    }

    await _client.from('customer_notification_preferences').upsert({
      'account_id': id,
      ...prefs.toJson(),
    });
  }

  static DateTime? _parseAuthTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _extensionForName(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _mimeFor(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}