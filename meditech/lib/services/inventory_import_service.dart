import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../config/env.dart';

class InventoryImportService {
  InventoryImportService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  // In-memory store for client-parsed CSV and XLSX batches.
  static final Map<String, Map<String, dynamic>> _localBatches = {};
  static final Map<String, List<Map<String, dynamic>>> _localRows = {};
  static Map<String, ({String id, String canonicalLabel})>?
      _cachedCatalogueMap;

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

  Future<Uint8List> downloadTemplate() async {
    try {
      final response = await http.get(
        _functionUri,
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Fall back to generating a clean CSV template locally
    }

    const csvTemplate =
        'Medicine (brand and strength),Stock quantity,Price per unit,Low-stock threshold,Nearest expiry date\r\n'
        'Biogesic 500 mg,240,4.50,20,2027-08-31\r\n';
    return Uint8List.fromList(utf8.encode(csvTemplate));
  }

  Future<Map<String, dynamic>> uploadFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.trim().toLowerCase().split('.').last;

    if (ext == 'csv') {
      final normalizedCsvBytes = _tryNormalizeCsvBytes(bytes);

      // Try the Edge Function first with normalized CSV headers
      try {
        final request = http.MultipartRequest('POST', _functionUri)
          ..headers.addAll(_authHeaders)
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              normalizedCsvBytes,
              filename: fileName,
            ),
          );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = _decodeResponse(response.body);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      } catch (_) {
        // Fall through to local CSV parser
      }

      return _parseRowsLocally(
        rawRows: _parseCsvString(utf8.decode(bytes, allowMalformed: true)),
        fileName: fileName,
      );
    }

    if (ext == 'xlsx') {
      // Try the Edge Function first
      try {
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

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = _decodeResponse(response.body);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      } catch (_) {
        // Fall through to local XLSX parser
      }

      // Parse .xlsx directly on the client (handles Excel serial dates & Google Sheets exports)
      final xlsxRows = _parseXlsxBytes(bytes);
      return _parseRowsLocally(
        rawRows: xlsxRows,
        fileName: fileName,
      );
    }

    throw Exception('Only CSV and XLSX files are supported.');
  }

  // Parses an .xlsx zip archive directly in Dart using package:archive and package:xml.
  List<List<String>> _parseXlsxBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read shared strings table if present (xl/sharedStrings.xml)
    final sharedStrings = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedFile != null) {
      final xmlStr = utf8.decode(sharedFile.content, allowMalformed: true);
      final doc = XmlDocument.parse(xmlStr);
      for (final si in doc.findAllElements('si')) {
        final buffer = StringBuffer();
        for (final t in si.findAllElements('t')) {
          buffer.write(t.innerText);
        }
        sharedStrings.add(buffer.toString());
      }
    }

    // 2. Find first worksheet (xl/worksheets/sheet1.xml or any xl/worksheets/*.xml)
    ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) {
      for (final f in archive.files) {
        if (f.isFile &&
            f.name.startsWith('xl/worksheets/') &&
            f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }
    }

    if (sheetFile == null) {
      throw Exception('The Excel file does not contain a valid worksheet.');
    }

    final sheetXml = utf8.decode(sheetFile.content, allowMalformed: true);
    final sheetDoc = XmlDocument.parse(sheetXml);

    final rows = <List<String>>[];

    for (final rowEl in sheetDoc.findAllElements('row')) {
      final rowCells = <int, String>{};
      int maxCol = -1;

      for (final c in rowEl.findElements('c')) {
        final refAttr = c.getAttribute('r') ?? '';
        final colIdx = _columnIndexFromCellRef(refAttr, maxCol + 1);
        if (colIdx > maxCol) maxCol = colIdx;

        final typeAttr = c.getAttribute('t') ?? '';
        String cellText = '';

        if (typeAttr == 'inlineStr') {
          final isEl = c.getElement('is');
          if (isEl != null) {
            final buf = StringBuffer();
            for (final t in isEl.findAllElements('t')) {
              buf.write(t.innerText);
            }
            cellText = buf.toString();
          }
        } else {
          final vEl = c.getElement('v');
          final rawVal = vEl?.innerText ?? '';
          if (typeAttr == 's') {
            final sIdx = int.tryParse(rawVal);
            if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
              cellText = sharedStrings[sIdx];
            }
          } else {
            cellText = rawVal;
          }
        }

        rowCells[colIdx] = cellText;
      }

      if (maxCol >= 0) {
        final list = List<String>.generate(
          maxCol + 1,
          (index) => rowCells[index] ?? '',
        );
        if (list.any((v) => v.trim().isNotEmpty)) {
          rows.add(list);
        }
      }
    }

    return rows;
  }

  int _columnIndexFromCellRef(String ref, int fallback) {
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(ref);
    if (letters == null || letters.isEmpty) return fallback;
    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      final code = letters.toUpperCase().codeUnitAt(i) - 64;
      col = col * 26 + code;
    }
    return col - 1;
  }

  // Normalizes flexible CSV headers into the exact 5 headers the Edge Function expects,
  // and strips out any accidental duplicate header lines inside the file.
  Uint8List _tryNormalizeCsvBytes(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      final rows = _parseCsvString(text);
      if (rows.isEmpty) return bytes;

      final firstRow = rows.first.map(_classifyColumn).toList();
      final medIdx = firstRow.indexOf('medicine');
      final stockIdx = firstRow.indexOf('stock');
      final priceIdx = firstRow.indexOf('price');
      final threshIdx = firstRow.indexOf('threshold');
      final expiryIdx = firstRow.indexOf('expiry');

      if (medIdx < 0 || stockIdx < 0 || priceIdx < 0) {
        return bytes;
      }

      final outLines = <String>[
        'Medicine (brand and strength),Stock quantity,Price per unit,Low-stock threshold,Nearest expiry date',
      ];

      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        if (_isHeaderRow(r)) continue;

        final med = medIdx < r.length ? r[medIdx].trim() : '';
        final stock = stockIdx < r.length ? r[stockIdx].trim() : '';
        final price = priceIdx < r.length ? r[priceIdx].trim() : '';
        final thresh =
            (threshIdx >= 0 && threshIdx < r.length) ? r[threshIdx].trim() : '';
        final expiry =
            (expiryIdx >= 0 && expiryIdx < r.length) ? r[expiryIdx].trim() : '';

        if (med.isEmpty && stock.isEmpty && price.isEmpty) continue;

        outLines.add(
          [
            _escapeCsvCell(med),
            _escapeCsvCell(stock),
            _escapeCsvCell(price),
            _escapeCsvCell(thresh),
            _escapeCsvCell(expiry),
          ].join(','),
        );
      }

      return Uint8List.fromList(utf8.encode(outLines.join('\r\n')));
    } catch (_) {
      return bytes;
    }
  }

  String _escapeCsvCell(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  String _classifyColumn(String rawHeader) {
    final h = rawHeader
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (h.contains('medicine') || h.contains('brand')) return 'medicine';
    if (h.contains('low') || h.contains('threshold')) return 'threshold';
    if (h.contains('stock') || h.contains('qty') || h.contains('quantity')) {
      return 'stock';
    }
    if (h.contains('price') || h.contains('cost') || h.contains('unit price')) {
      return 'price';
    }
    if (h.contains('expiry') || h.contains('expiration') || h.contains('date')) {
      return 'expiry';
    }
    return '';
  }

  bool _isHeaderRow(List<String> row) {
    final classified = row.map(_classifyColumn).toSet();
    return classified.contains('medicine') &&
        classified.contains('stock') &&
        classified.contains('price');
  }

  List<List<String>> _parseCsvString(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var insideQuotes = false;

    final cleaned = input.replaceFirst(RegExp(r'^\uFEFF'), '');

    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < cleaned.length && cleaned[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
        continue;
      }

      if (char == ',' && !insideQuotes) {
        row.add(cell.toString());
        cell.clear();
        continue;
      }

      if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < cleaned.length && cleaned[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell.clear();
        if (row.any((v) => v.trim().isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
        continue;
      }

      cell.write(char);
    }

    row.add(cell.toString());
    if (row.any((v) => v.trim().isNotEmpty)) {
      rows.add(row);
    }

    return rows;
  }

  // Normalizes both spaces and number-unit boundaries (so "Advil 200mg" == "Advil 200 mg")
  String _normMed(String s) => s
      .trim()
      .toLowerCase()
      .replaceAllMapped(
        RegExp(r'(\d)\s*([a-z%])'),
        (m) => '${m[1]}${m[2]}',
      )
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<Map<String, ({String id, String canonicalLabel})>>
      _loadActiveCatalogueMap() async {
    try {
      final rows = await _client
          .from('medicines')
          .select('id, brand_name, strength')
          .eq('status', 'active');

      final map = <String, ({String id, String canonicalLabel})>{};
      for (final r in rows) {
        final id = r['id']?.toString() ?? '';
        final brand = (r['brand_name']?.toString() ?? '').trim();
        final strength = (r['strength']?.toString() ?? '').trim();
        if (id.isNotEmpty) {
          final full = '$brand $strength'.trim();
          final entry = (id: id, canonicalLabel: full);
          map[_normMed(full)] = entry;
          map[_normMed(brand)] = entry;
        }
      }
      _cachedCatalogueMap = map;
      return map;
    } catch (_) {
      return _cachedCatalogueMap ??
          <String, ({String id, String canonicalLabel})>{};
    }
  }

  DateTime? _parseFlexibleExpiryDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Standard ISO YYYY-MM-DD
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    // 2. Excel serial date number (e.g. "46981" or "46981.0")
    final serial = double.tryParse(text);
    if (serial != null && serial > 20000 && serial < 100000) {
      final utcMs = ((serial - 25569) * 86400 * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
    }

    // 3. MM/DD/YYYY or M/D/YYYY
    final slashParts = text.split('/');
    if (slashParts.length == 3) {
      final m = int.tryParse(slashParts[0]);
      final d = int.tryParse(slashParts[1]);
      final y = int.tryParse(slashParts[2]);
      if (m != null && d != null && y != null && y >= 2000) {
        return DateTime.utc(y, m, d);
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _parseRowsLocally({
    required List<List<String>> rawRows,
    required String fileName,
  }) async {
    if (rawRows.length < 2) {
      throw Exception(
        'The file must contain a header and at least one data row.',
      );
    }

    final headerClasses = rawRows.first.map(_classifyColumn).toList();
    final medIdx = headerClasses.indexOf('medicine');
    final stockIdx = headerClasses.indexOf('stock');
    final priceIdx = headerClasses.indexOf('price');
    final threshIdx = headerClasses.indexOf('threshold');
    final expiryIdx = headerClasses.indexOf('expiry');

    if (medIdx < 0 || stockIdx < 0 || priceIdx < 0) {
      throw Exception(
        'Missing required columns. Expected Medicine, Stock quantity, and Price per unit.',
      );
    }

    final catalogueMap = await _loadActiveCatalogueMap();
    final batchId = 'local-batch-${DateTime.now().millisecondsSinceEpoch}';
    final stagedRows = <Map<String, dynamic>>[];
    final seenMedicineKeys = <String>{};

    var rowNum = 2;
    for (var i = 1; i < rawRows.length; i++) {
      final cells = rawRows[i];
      if (_isHeaderRow(cells)) continue;

      var medLabel = medIdx < cells.length ? cells[medIdx].trim() : '';
      final stockStr = stockIdx < cells.length ? cells[stockIdx].trim() : '';
      final priceStr = priceIdx < cells.length ? cells[priceIdx].trim() : '';
      final threshStr =
          (threshIdx >= 0 && threshIdx < cells.length) ? cells[threshIdx].trim() : '';
      final expiryStr =
          (expiryIdx >= 0 && expiryIdx < cells.length) ? cells[expiryIdx].trim() : '';

      if (medLabel.isEmpty && stockStr.isEmpty && priceStr.isEmpty) continue;

      final medNorm = _normMed(medLabel);
      if (medNorm.isNotEmpty && seenMedicineKeys.contains(medNorm)) {
        continue;
      }
      if (medNorm.isNotEmpty) {
        seenMedicineKeys.add(medNorm);
      }

      // Stock in Excel may come as "600" or "600.0"
      final stockNum = double.tryParse(stockStr);
      final stockVal = (stockNum != null && stockNum == stockNum.roundToDouble())
          ? stockNum.round()
          : int.tryParse(stockStr);

      final priceVal = double.tryParse(priceStr);

      final threshNum = double.tryParse(threshStr);
      final threshVal = threshStr.isEmpty
          ? null
          : ((threshNum != null && threshNum == threshNum.roundToDouble())
              ? threshNum.round()
              : int.tryParse(threshStr));

      final expiryDate = _parseFlexibleExpiryDate(expiryStr);

      final errors = <String>[];
      if (medLabel.isEmpty) {
        errors.add('Medicine is required.');
      }
      if (stockStr.isEmpty) {
        errors.add('Stock quantity is required.');
      } else if (stockVal == null || stockVal < 0) {
        errors.add('Stock quantity must be a non-negative whole number.');
      }
      if (priceStr.isEmpty) {
        errors.add('Price is missing.');
      } else if (priceVal == null || priceVal <= 0) {
        errors.add('Price must be greater than zero.');
      }
      if (threshStr.isNotEmpty && (threshVal == null || threshVal < 1)) {
        errors.add('Low-stock threshold must be at least 1.');
      }
      if (expiryStr.isNotEmpty && expiryDate == null) {
        errors.add('Nearest expiry date must use YYYY-MM-DD.');
      }

      String? matchedMedId;
      if (medLabel.isNotEmpty && catalogueMap.isNotEmpty) {
        final match = catalogueMap[medNorm];
        if (match != null) {
          matchedMedId = match.id;
          medLabel = match.canonicalLabel;
        } else {
          errors.add(
            '"$medLabel" isn\'t in the MediTech catalogue. Fix the name, or remove this row and request it from the administrator.',
          );
        }
      }

      stagedRows.add({
        'id': '$batchId-row-$rowNum',
        'batch_id': batchId,
        'source_row_number': rowNum,
        'medicine_label': medLabel,
        'matched_medicine_id': matchedMedId,
        'stock_quantity': stockVal ?? stockStr,
        'price_per_unit':
            priceVal != null ? priceVal.toStringAsFixed(2) : priceStr,
        'low_stock_threshold': threshVal ?? 10,
        'nearest_expiry':
            expiryDate != null ? _dateOnly(expiryDate) : expiryStr,
        'errors': errors,
        'warnings': <String>[],
      });
      rowNum++;
    }

    if (stagedRows.isEmpty) {
      throw Exception('The file does not contain any data rows.');
    }

    final validCount =
        stagedRows.where((r) => (r['errors'] as List).isEmpty).length;
    final errorCount = stagedRows.length - validCount;

    final batchData = <String, dynamic>{
      'id': batchId,
      'file_name': fileName,
      'status': 'reviewing',
      'total_rows': stagedRows.length,
      'valid_rows': validCount,
      'error_rows': errorCount,
    };

    _localBatches[batchId] = batchData;
    _localRows[batchId] = stagedRows;

    return {
      'batch_id': batchId,
      'file_name': fileName,
      'total_rows': stagedRows.length,
      'valid_rows': validCount,
      'error_rows': errorCount,
      'status': 'reviewing',
    };
  }

  /// Loads one import batch.
  Future<Map<String, dynamic>> loadBatch(String batchId) async {
    if (_localBatches.containsKey(batchId)) {
      return Map<String, dynamic>.from(_localBatches[batchId]!);
    }

    final result = await _client
        .from('inventory_import_batches')
        .select()
        .eq('id', batchId)
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Loads all staged rows in a batch.
  Future<List<Map<String, dynamic>>> loadRows(String batchId) async {
    if (_localRows.containsKey(batchId)) {
      return [
        for (final r in _localRows[batchId]!) Map<String, dynamic>.from(r),
      ];
    }

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
    for (final entry in _localRows.entries) {
      final idx = entry.value.indexWhere((r) => r['id'] == rowId);
      if (idx >= 0) {
        final catalogueMap =
            _cachedCatalogueMap ?? await _loadActiveCatalogueMap();
        final row = entry.value[idx];
        final errors = <String>[];
        var cleanMed = medicineLabel.trim();

        if (cleanMed.isEmpty) {
          errors.add('Medicine is required.');
        }
        if (stockQuantity < 0) {
          errors.add('Stock quantity cannot be negative.');
        }
        if (pricePerUnit <= 0) {
          errors.add('Price must be greater than zero.');
        }
        if (lowStockThreshold != null && lowStockThreshold < 1) {
          errors.add('Low-stock threshold must be at least 1.');
        }

        String? matchedId;
        if (cleanMed.isNotEmpty && catalogueMap.isNotEmpty) {
          final match = catalogueMap[_normMed(cleanMed)];
          if (match != null) {
            matchedId = match.id;
            cleanMed = match.canonicalLabel;
          } else {
            errors.add(
              '"$cleanMed" isn\'t in the MediTech catalogue. Fix the name, or remove this row and request it from the administrator.',
            );
          }
        }

        row['medicine_label'] = cleanMed;
        row['matched_medicine_id'] = matchedId;
        row['stock_quantity'] = stockQuantity;
        row['price_per_unit'] = pricePerUnit.toStringAsFixed(2);
        row['low_stock_threshold'] = lowStockThreshold;
        row['nearest_expiry'] =
            nearestExpiry == null ? null : _dateOnly(nearestExpiry);
        row['errors'] = errors;

        _recalcLocalBatch(entry.key);
        return {'row_id': rowId, 'valid': errors.isEmpty};
      }
    }

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
    for (final entry in _localRows.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((r) => r['id'] == rowId);
      if (entry.value.length != before) {
        _recalcLocalBatch(entry.key);
        return {'removed': true};
      }
    }

    return _client.rpc(
      'remove_inventory_import_row',
      params: {'p_row_id': rowId},
    );
  }

  Future<dynamic> publishImport(String batchId) async {
    if (_localBatches.containsKey(batchId)) {
      final rows = _localRows[batchId] ?? [];
      final existingRows = await _client
          .from('inventory_items')
          .select('id, medicine_id');
      final existingByMedId = <String, String>{
        for (final r in existingRows)
          if (r['medicine_id'] != null && r['id'] != null)
            r['medicine_id'].toString(): r['id'].toString(),
      };

      for (final row in rows) {
        final medId = row['matched_medicine_id']?.toString();
        if (medId == null || medId.isEmpty) continue;

        final stock = int.tryParse(row['stock_quantity'].toString()) ?? 0;
        final price = double.tryParse(row['price_per_unit'].toString()) ?? 0;
        final threshold = row['low_stock_threshold'] == null
            ? 10
            : (int.tryParse(row['low_stock_threshold'].toString()) ?? 10);
        final expiryStr = row['nearest_expiry']?.toString();
        final hasExpiry = expiryStr != null &&
            expiryStr.isNotEmpty &&
            DateTime.tryParse(expiryStr) != null;

        final existingItemId = existingByMedId[medId];
        if (existingItemId != null) {
          await _client.rpc('update_inventory_item', params: {
            'p_item_id': existingItemId,
            'p_stock_quantity': stock,
            'p_price_per_unit': price,
            'p_low_stock_threshold': threshold,
            'p_nearest_expiry': hasExpiry ? expiryStr : null,
            'p_clear_expiry': !hasExpiry,
          });
        } else {
          await _client.rpc('add_inventory_item', params: {
            'p_medicine_id': medId,
            'p_stock_quantity': stock,
            'p_price_per_unit': price,
            'p_low_stock_threshold': threshold,
            'p_nearest_expiry': hasExpiry ? expiryStr : null,
          });
        }
      }

      _localBatches[batchId]!['status'] = 'published';
      return {'published': true, 'batch_id': batchId};
    }

    return _client.rpc(
      'publish_import',
      params: {'p_batch_id': batchId},
    );
  }

  Future<dynamic> discardImport(String batchId) async {
    if (_localBatches.containsKey(batchId)) {
      _localRows[batchId]?.clear();
      _localBatches[batchId]!['status'] = 'discarded';
      _localBatches[batchId]!['total_rows'] = 0;
      _localBatches[batchId]!['valid_rows'] = 0;
      _localBatches[batchId]!['error_rows'] = 0;
      return {'discarded': true, 'batch_id': batchId};
    }

    return _client.rpc(
      'discard_import',
      params: {'p_batch_id': batchId},
    );
  }

  void _recalcLocalBatch(String batchId) {
    final batch = _localBatches[batchId];
    final rows = _localRows[batchId];
    if (batch == null || rows == null) return;
    final valid = rows.where((r) => (r['errors'] as List).isEmpty).length;
    batch['total_rows'] = rows.length;
    batch['valid_rows'] = valid;
    batch['error_rows'] = rows.length - valid;
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
