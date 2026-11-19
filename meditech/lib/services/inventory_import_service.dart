
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class InventoryImportService {
  InventoryImportService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Uri get _functionUri {
    final baseUrl = Env.supabaseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$baseUrl/functions/v1/import-parse');
  }

  Map<String, String> get _authHeaders {
    final session = _client.auth.currentSession;

    if (session == null) {
      throw Exception('You must be signed in to import inventory.');
    }

    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'apikey': Env.supabasePublishableKey,
    };
  }

  dynamic _decodeResponse(String body) {
    if (body.isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Exception _responseError(http.Response response) {
    final decoded = _decodeResponse(response.body);

    if (decoded is Map) {
      return Exception(
        decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            'Import request failed (${response.statusCode}).',
      );
    }

    return Exception(
      decoded?.toString() ??
          'Import request failed (${response.statusCode}).',
    );
  }

  Future<Uint8List> downloadTemplate() async {
    final response = await http.get(
      _functionUri,
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw _responseError(response);
    }

    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest('POST', _functionUri)
      ..headers.addAll(_authHeaders)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response);
    }

    final decoded = _decodeResponse(response.body);

    if (decoded is! Map) {
      throw Exception('The import server returned an invalid response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  /// Loads one import batch.
  Future<Map<String, dynamic>> loadBatch(String batchId) async {
    final result = await _client
        .from('inventory_import_batches')
        .select()
        .eq('id', batchId)
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Loads all staged rows in a batch.
  Future<List<Map<String, dynamic>>> loadRows(String batchId) async {
    final result = await _client
        .from('inventory_import_rows')
        .select()
        .eq('batch_id', batchId)
        .order('source_row_number');

    return List<Map<String, dynamic>>.from(result);
  }

  Future<dynamic> updateRow({
    required String rowId,
    required String medicineLabel,
    required int stockQuantity,
    required double pricePerUnit,
    int? lowStockThreshold,
    DateTime? nearestExpiry,
  }) async {
    return _client.rpc(
      'update_inventory_import_row',
      params: {
        'p_row_id': rowId,
        'p_medicine_label': medicineLabel,
        'p_stock_quantity': stockQuantity,
        'p_price_per_unit': pricePerUnit,
        'p_low_stock_threshold': lowStockThreshold,
        'p_nearest_expiry':
            nearestExpiry == null ? null : _dateOnly(nearestExpiry),
      },
    );
  }

  Future<dynamic> removeRow(String rowId) async {
    return _client.rpc(
      'remove_inventory_import_row',
      params: {'p_row_id': rowId},
    );
  }

  Future<dynamic> publishImport(String batchId) async {
    return _client.rpc(
      'publish_import',
      params: {'p_batch_id': batchId},
    );
  }

  Future<dynamic> discardImport(String batchId) async {
    return _client.rpc(
      'discard_import',
      params: {'p_batch_id': batchId},
    );
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
