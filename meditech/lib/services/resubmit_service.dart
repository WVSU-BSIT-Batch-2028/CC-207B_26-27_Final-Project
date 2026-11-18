import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy_application.dart';
import 'registration_service.dart';

// Loads and resubmits the signed-in owner's rejected application
class ResubmitService {
  ResubmitService(this._client);

  final SupabaseClient _client;

  // The rejected application, for filling in the form
  Future<Map<String, dynamic>?> load() async {
    final json = await _client.rpc('my_application_for_edit');
    return json == null ? null : Map<String, dynamic>.from(json as Map);
  }

  // Upload any new files, then save the edited application
  Future<void> resubmit(
    Map<String, dynamic> details, {
    PickedDocument? ltoFile,
    PickedDocument? storefrontFile,
  }) async {
    try {
      final branchId = await _client.rpc('my_branch_id') as String;
      final documents = <Map<String, dynamic>>[];

      // Upload a new file into this branch's own folder
      Future<void> upload(String kind, PickedDocument? doc) async {
        if (doc == null) return;
        final ext = doc.mimeType == 'application/pdf' ? 'pdf' : doc.mimeType == 'image/png' ? 'png' : 'jpg';
        final path = '$branchId/$kind/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _client.storage
            .from('pharmacy-documents')
            .uploadBinary(path, doc.bytes, fileOptions: FileOptions(contentType: doc.mimeType));
        documents.add({'kind': kind, 'path': path, 'mime_type': doc.mimeType, 'size_bytes': doc.bytes.length});
      }

      await upload('lto', ltoFile);
      await upload('storefront', storefrontFile);

      await _client.rpc('resubmit_pharmacy_application', params: {
        'p': {...details, 'documents': documents},
      });
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('LTO_EXPIRED')) {
        throw RegistrationException('This LTO has expired.', {'lto_expiry': 'Expired.'});
      }
      if (msg.contains('lto_number')) {
        throw RegistrationException('This LTO number is already registered.', {'lto_number': 'Already registered.'});
      }
      if (msg.contains('NOT_REJECTED')) {
        throw RegistrationException('This application is already waiting for review.');
      }
      throw RegistrationException('Could not resubmit. Please try again.');
    } on StorageException {
      throw RegistrationException('A file could not be uploaded. Please try again.');
    } catch (e) {
      if (e is RegistrationException) rethrow;
      throw RegistrationException('No internet connection. Please try again.');
    }
  }
}