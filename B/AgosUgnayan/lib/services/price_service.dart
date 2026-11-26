// Monthly reference prices (prices collection). The last loaded prices are
// also saved on the phone with shared_preferences, so the Prices tab still
// works without internet and says when the copy was saved.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_record.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';
import '../utils/crop_catalog.dart';
import '../utils/format.dart';

/// The prices plus where they came from.
class PriceData {
  const PriceData(this.records, {this.savedCopyFrom});

  final List<PriceRecord> records;

  /// Set when the internet failed and we show the copy saved on this date.
  final DateTime? savedCopyFrom;
}

/// Loading and saving reference prices.
class PriceService {
  static const _cacheKey = 'prices_cache';
  static const _cacheTimeKey = 'prices_cache_time';

  CollectionReference<Map<String, dynamic>> get _prices =>
      FirebaseFirestore.instance.collection('prices');

  /// Loads the last 12 months of prices for every crop. If that fails, falls
  /// back to the copy saved on this phone. Throws only if there is no copy.
  Future<PriceData> fetchRecent() async {
    try {
      final records = await runSafely('load prices', () async {
        final now = DateTime.now();
        final from = monthKeyOf(DateTime(now.year - 1, now.month));
        final snapshot = await _prices
            .where('month', isGreaterThanOrEqualTo: from)
            .get();
        return snapshot.docs
            .map((doc) => PriceRecord.fromMap(doc.data()))
            .toList();
      });
      await _saveCopy(records);
      return PriceData(withReferencePrices(records));
    } on AppException {
      final copy = await _loadCopy();
      if (copy == null) rethrow; // no saved copy: show the error
      return PriceData(
        withReferencePrices(copy.records),
        savedCopyFrom: copy.savedCopyFrom,
      );
    }
  }

  /// Saves (or replaces) one crop's price for one month. Admin only.
  Future<void> save(PriceRecord record, String adminId) {
    return runSafely('save price', () {
      return _prices.doc(record.docId).set({
        ...record.toMap(),
        'enteredBy': adminId,
        'enteredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Saves many prices at once (the PSA import). Each price uses the same
  /// document id as [save] (crop_month), so importing again updates the
  /// price instead of adding a duplicate. Admin only.
  Future<void> saveMany(List<PriceRecord> records, String adminId) {
    return runSafely('save PSA prices', () async {
      // A batch writes everything together: all of it is saved, or none.
      // Firestore allows 500 writes per batch, so split bigger imports.
      for (var start = 0; start < records.length; start += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final record in records.skip(start).take(450)) {
          batch.set(_prices.doc(record.docId), {
            ...record.toMap(),
            'source': 'PSA OpenSTAT',
            'enteredBy': adminId,
            'enteredAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    });
  }

  /// The PSA reference prices from the crop catalog (one per crop, each
  /// with the month PSA published it), as price records.
  static List<PriceRecord> referenceRecords() => [
    for (final crop in kCropCatalog)
      PriceRecord(
        crop: crop.name,
        month: crop.referenceMonth,
        price: crop.referencePrice,
      ),
  ];

  /// [records] plus every catalog reference price that is not already there
  /// (same crop and month). So every crop has at least one price, even when
  /// the database has none yet, and a database price always wins.
  static List<PriceRecord> withReferencePrices(List<PriceRecord> records) {
    final have = {for (final record in records) record.docId};
    return [
      ...records,
      for (final reference in referenceRecords())
        if (!have.contains(reference.docId)) reference,
    ];
  }

  /// Saves the catalog's reference prices to the database (admin only) and
  /// returns how many were added. It skips every crop and month that already
  /// has a price (e.g. from "Get latest PSA prices"), so a real PSA import
  /// always wins and nothing is duplicated (same crop_month document id).
  Future<int> saveReferencePrices(String adminId) async {
    final references = referenceRecords();
    final oldest = references
        .map((r) => r.month)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final existing = await runSafely('load prices', () async {
      final snapshot = await _prices
          .where('month', isGreaterThanOrEqualTo: oldest)
          .get();
      return {for (final doc in snapshot.docs) doc.id};
    });
    final missing = missingReferences(references, existing);
    if (missing.isNotEmpty) await saveMany(missing, adminId);
    return missing.length;
  }

  /// The [references] whose crop and month is not in [existingIds] yet.
  static List<PriceRecord> missingReferences(
    List<PriceRecord> references,
    Set<String> existingIds,
  ) => [
    for (final reference in references)
      if (!existingIds.contains(reference.docId)) reference,
  ];

  /// The newest month of all [records], e.g. "2026-06" (null when empty).
  static String? newestMonth(List<PriceRecord> records) {
    if (records.isEmpty) return null;
    return records
        .map((record) => record.month)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  }

  /// True when [crop]'s newest price is from before the newest month of all
  /// prices. Such a price is labeled "Older price" and never shown as current.
  static bool isOlderPrice(String crop, List<PriceRecord> records) {
    final latest = latestFor(crop, records);
    final newest = newestMonth(records);
    return latest != null &&
        newest != null &&
        latest.month.compareTo(newest) < 0;
  }

  /// How much [crop]'s price changed since the month just before its newest
  /// price. Null when there is no price for exactly the month before (we
  /// never compare months that are far apart).
  static double? monthlyChange(String crop, List<PriceRecord> records) {
    final history = historyFor(crop, records);
    if (history.length < 2) return null;
    final latest = history.last;
    final previous = history[history.length - 2];
    final date = DateTime.parse('${latest.month}-01');
    final monthBefore = monthKeyOf(DateTime(date.year, date.month - 1));
    if (previous.month != monthBefore) return null;
    return latest.price - previous.price;
  }

  /// The newest price for [crop] from [records], or null if there is none.
  static PriceRecord? latestFor(String crop, List<PriceRecord> records) {
    final forCrop = historyFor(crop, records);
    return forCrop.isEmpty ? null : forCrop.last;
  }

  /// All prices of one crop, oldest month first (the order the chart needs).
  static List<PriceRecord> historyFor(String crop, List<PriceRecord> records) {
    final list = records.where((r) => r.crop == crop).toList();
    list.sort((a, b) => a.month.compareTo(b.month));
    return list;
  }

  Future<void> _saveCopy(List<PriceRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(records.map((r) => r.toMap()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      AppLogger.error('saving price copy failed', e); // not fatal
    }
  }

  Future<PriceData?> _loadCopy() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheKey);
    final time = prefs.getString(_cacheTimeKey);
    if (json == null || time == null) return null;
    final list = (jsonDecode(json) as List)
        .map((item) => PriceRecord.fromMap(item as Map<String, dynamic>))
        .toList();
    return PriceData(list, savedCopyFrom: DateTime.parse(time));
  }
}
