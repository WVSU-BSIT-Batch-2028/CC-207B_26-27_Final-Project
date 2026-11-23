import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/public_media_urls.dart';

import '../models/catalogue_medicine.dart';
import '../models/drug_registration.dart';
import '../models/verification_check.dart';

// Admin work on the medicine catalogue
class CatalogueService {
  CatalogueService(this._client);

  final SupabaseClient _client;

  // The catalogue table, with an optional status filter and search
  Future<List<CatalogueMedicine>> list({String? status, String? search}) async {
    final rows = await _client.rpc('admin_list_medicines', params: {
      'p_status': status,
      'p_search': search,
    }) as List;
    return rows.map((r) => CatalogueMedicine.fromJson(r as Map<String, dynamic>)).toList();
  }

  // The dosage form list
  Future<List<LookupItem>> dosageForms() async {
    final rows = await _client.from('dosage_forms').select('id, name').order('name');
    return rows.map(LookupItem.fromJson).toList();
  }

  // The selling unit list
  Future<List<LookupItem>> units() async {
    final rows = await _client.from('units').select('id, name').order('name');
    return rows.map(LookupItem.fromJson).toList();
  }

  // One registration's details
  Future<DrugRegistration?> registration(String id) async {
    final row = await _client.from('drug_registrations').select().eq('id', id).maybeSingle();
    return row == null ? null : DrugRegistration.fromJson(row);
  }

  // Save a registration; returns its id
  Future<String> saveRegistration(Map<String, dynamic> details) async {
    return await _client.rpc('admin_save_registration', params: {'p': details}) as String;
  }

  /// Existing CPR row id, for linking seed/demo medicines or another pack size.
  Future<String?> registrationIdByNumber(String registrationNumber) async {
    final num = registrationNumber.trim();
    if (num.isEmpty) return null;
    final row = await _client
        .from('drug_registrations')
        .select('id')
        .eq('registration_number', num)
        .maybeSingle();
    return row?['id'] as String?;
  }

  // Save a catalogue entry; returns its id
  Future<String> saveMedicine(Map<String, dynamic> details) async {
    return await _client.rpc('admin_save_medicine', params: {'p': details}) as String;
  }

  /// Upload pack image to public `medicine-images`; returns storage path for `image_path`.
  Future<String> uploadMedicineImage({
    required String medicineId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final ext = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = 'catalogue/$medicineId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(medicineImagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return path;
  }

  // A registration's FDA checks, newest first
  Future<List<VerificationCheck>> checks(String registrationId) async {
    final rows = await _client
        .from('verification_checks')
        .select()
        .eq('subject_type', 'drug_registration')
        .eq('subject_id', registrationId)
        .order('checked_at', ascending: false);
    return rows.map((r) => VerificationCheck.fromJson(r)).toList();
  }

  // Is there a "matched" check on the registration's current details?
  Future<bool> hasMatch(String registrationId) async {
    return await _client.rpc('registration_has_current_match',
        params: {'p_registration_id': registrationId}) as bool;
  }

  // Save a new product FDA check
  Future<void> recordCheck(String registrationId, String result, String? notes) async {
    await _client.rpc('record_registration_verification', params: {
      'p_registration_id': registrationId,
      'p_result': result,
      'p_notes': notes,
    });
  }

  // Make a catalogue entry Active or Inactive
  Future<void> setStatus(String medicineId, String status, [String? reason]) async {
    await _client.rpc('set_medicine_status', params: {
      'p_medicine_id': medicineId,
      'p_status': status,
      'p_reason': reason,
    });
  }

  // Turn server errors into messages for the admin
  static String friendlyError(Object error) {
    if (error is PostgrestException) {
      final msg = error.message;
      if (error.code == '23505') {
        return msg.contains('registration_number')
            ? 'That registration number is already on file. If you are adding another pack size, '
                'choose a different unit or pack description.'
            : 'This medicine is already in the catalogue with that unit and pack.';
      }
      if (msg.contains('NEEDS_FDA_CHECK')) {
        return 'Record a "Matched and valid" FDA check on this registration first.';
      }
      if (msg.contains('REASON_LENGTH')) return 'The reason must be 5 to 200 characters.';
      if (msg.contains('NEEDS_REGISTRATION')) return 'Save the registration first.';
      if (msg.contains('NOT_ALLOWED')) return 'Only administrators can do this.';
    }
    return 'Something went wrong. Please try again.';
  }
}