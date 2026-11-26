// The buyer assistant's facts, worked out in plain Dart: price
// comparisons, totals, stock checks, order meanings and listing search.
// The AI only puts these into words, so the numbers never depend on it,
// and they still work when the AI is busy (the fallback).

import 'dart:convert';

import '../models/assistant.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/price_record.dart';
import '../services/price_service.dart';
import 'constants.dart';
import 'format.dart';

// ------------------------------------------------------------ price check

/// A farmer's asking price compared with the PSA reference price.
class PriceComparison {
  const PriceComparison({
    required this.crop,
    required this.reference,
    this.asking,
    this.unit = 'kg',
    this.isOlder = false,
  });

  final String crop;
  final PriceRecord? reference; // null when PSA has no price for the crop
  final double? asking; // null on a price page (no farmer price)
  final String unit;
  final bool isOlder; // the reference is older than the newest PSA month

  /// Asking − reference, in pesos (null when one is missing, or when the
  /// listing is not sold per kg: PSA prices are per kg).
  double? get difference {
    final a = asking, r = reference;
    if (a == null || r == null || unit != 'kg') return null;
    return ((a - r.price) * 100).round() / 100;
  }

  /// The difference as a percent of the reference, e.g. 11.8.
  double? get percent {
    final d = difference, r = reference;
    if (d == null || r == null || r.price == 0) return null;
    return (d / r.price * 1000).round() / 10;
  }

  /// "higher", "lower" or "about the same" (within 5%).
  String? get verdict {
    final p = percent;
    if (p == null) return null;
    if (p.abs() <= 5) return 'about the same as';
    return p > 0 ? 'higher than' : 'lower than';
  }

  /// "Jun 2026", plus "(older price)" when it is old.
  String? get monthText {
    final r = reference;
    if (r == null) return null;
    final month = formatMonthKey(r.month);
    return isOlder ? '$month (older price)' : month;
  }

  List<FactRow> get facts => [
    if (asking != null) FactRow('Asking price', '${formatPeso(asking!)}/$unit'),
    if (reference != null)
      FactRow('PSA reference', '${formatPeso(reference!.price)}/kg'),
    if (monthText != null) FactRow('PSA month', monthText!),
    if (reference == null) const FactRow('PSA reference', 'None for this crop'),
    if (difference != null)
      FactRow(
        'Difference',
        '${difference! >= 0 ? '+' : '−'}${formatPeso(difference!.abs())} '
            '(${percent! >= 0 ? '+' : '−'}${percent!.abs()}%)',
      ),
  ];

  /// One plain sentence, used when the AI is busy.
  String get plainAnswer {
    final r = reference;
    if (r == null) {
      return 'PSA has no farmgate price for $crop yet, so there is nothing '
          'to compare with.';
    }
    final psa =
        'The PSA farmgate price for $crop is ${formatPeso(r.price)}/kg '
        '($monthText). That is what farmers were paid on average in '
        'Iloilo Province.';
    if (asking == null) return psa;
    if (difference == null) {
      return '$psa This listing is sold per $unit, so it can\'t be compared '
          'per kg.';
    }
    return '$psa This asking price is $verdict that, by '
        '${formatPeso(difference!.abs())} (${percent!.abs()}%).';
  }

  Map<String, dynamic> toFacts() => {
    'crop': crop,
    'askingPrice': ?asking,
    'unit': unit,
    'psaReferencePerKg': ?reference?.price,
    'psaMonth': ?monthText,
    'differencePesos': ?difference,
    'differencePercent': ?percent,
    'comparison': ?verdict,
    if (isOlder) 'warnings': ['This PSA price is old: $monthText.'],
    'psaMeaning':
        'PSA farmgate price = the average price farmers were paid in Iloilo '
        'Province that month, before transport and selling costs.',
  };
}

/// Compares [asking] (optional) with the newest PSA price of [crop].
PriceComparison comparePrice(
  String crop,
  List<PriceRecord> records, {
  double? asking,
  String unit = 'kg',
}) {
  return PriceComparison(
    crop: crop,
    reference: PriceService.latestFor(crop, records),
    asking: asking,
    unit: unit,
    isOlder: PriceService.isOlderPrice(crop, records),
  );
}

// ------------------------------------------------------------------ trend

/// How [crop]'s PSA price moved, only from the months we have.
List<FactRow> trendFacts(String crop, List<PriceRecord> records) {
  final mine = records.where((r) => r.crop == crop).toList()
    ..sort((a, b) => a.month.compareTo(b.month));
  if (mine.length < 2) {
    return [
      FactRow('PSA months we have', '${mine.length}'),
      const FactRow('Trend', 'Not enough months to tell'),
    ];
  }
  final first = mine.first, last = mine.last;
  final change = PriceService.monthlyChange(crop, records);
  final overall = last.price - first.price;
  return [
    FactRow(
      'Newest',
      '${formatPeso(last.price)}/kg (${formatMonthKey(last.month)})',
    ),
    if (change != null)
      FactRow(
        'Since the month before',
        '${change >= 0 ? '+' : '−'}${formatPeso(change.abs())}',
      ),
    FactRow(
      'Since ${formatMonthKey(first.month)}',
      '${overall >= 0 ? '+' : '−'}${formatPeso(overall.abs())}',
    ),
  ];
}

// ------------------------------------------------------------- offer math

/// The total for [qty] at [price], and whether enough is available.
List<FactRow> offerFacts({
  required double qty,
  required double price,
  required String unit,
  double? available,
}) {
  final total = orderTotal(qty, price);
  return [
    FactRow('Amount', '${formatQuantity(qty)} $unit'),
    FactRow('Price', '${formatPeso(price)}/$unit'),
    FactRow('Total', formatPeso(total)),
    if (available != null)
      FactRow(
        'Available now',
        qty <= available
            ? '${formatQuantity(available)} $unit (enough)'
            : 'Only ${formatQuantity(available)} $unit available',
      ),
  ];
}

/// What an order's state means, in plain words.
String orderMeaning(CropOrder order, DateTime now) {
  final until = order.reservedUntil;
  return switch (order.stateAt(now)) {
    OrderState.pending =>
      'Waiting for the farmer to answer. Nothing is held for you yet. It '
          'expires on ${formatDate(order.answerBy)}.',
    OrderState.offered =>
      'The farmer offered this. You can accept or decline it until '
          '${formatDate(order.answerBy)}.',
    OrderState.reserved =>
      'Reserved: the farmer is holding it for you'
          '${until == null ? '' : ' until ${formatDate(until)}'}. Agree on '
          'pickup and payment in the chat.',
    OrderState.holdEnded =>
      'The hold ended${until == null ? '' : ' on ${formatDate(until)}'}. '
          'The stock is free again; message the farmer.',
    OrderState.completed => 'Sold: the farmer marked it as sold.',
    OrderState.declined => 'Declined.',
    OrderState.cancelled => 'Cancelled.',
    OrderState.expired => 'Expired: nobody answered within 3 days.',
  };
}

List<FactRow> orderFacts(CropOrder order, DateTime now) => [
  FactRow('Order', '${order.crop}, ${formatQuantity(order.qty)} ${order.unit}'),
  FactRow('Price', '${formatPeso(order.price)}/${order.unit}'),
  FactRow('Total', formatPeso(order.total)),
  FactRow('Status', orderMeaning(order, now)),
];

// ----------------------------------------------------------------- search

/// How to sort search results.
enum SearchSort { price, available, newest }

/// A listing search the app can run: only crops and towns we know.
class SearchQuery {
  const SearchQuery({
    this.crop,
    this.town,
    this.quantity,
    this.sort = SearchSort.price,
  });

  final String? crop; // one of kCrops, or null for any crop
  final String? town; // one of kTowns, or null for any town
  final double? quantity; // how much the buyer wants, if said
  final SearchSort sort;

  bool get isEmpty => crop == null && town == null;
}

/// The crop in [name], matching our names and local names (case-insensitive),
/// or null when it is not one of our 71 crops.
String? matchCrop(String? name) {
  if (name == null) return null;
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final crop in kCropCatalog) {
    if (crop.name.toLowerCase() == wanted ||
        crop.localNames.any((n) => n.toLowerCase() == wanted)) {
      return crop.name;
    }
  }
  return null;
}

/// The town in [name] if it is one of ours, else null.
String? matchTown(String? name) {
  if (name == null) return null;
  final wanted = name.trim().toLowerCase();
  for (final town in kTowns) {
    if (town.toLowerCase() == wanted) return town;
  }
  return null;
}

/// A quantity between 0 and 100,000 (anything else is dropped).
double? clampQuantity(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || number <= 0) return null;
  return number > 100000 ? 100000 : number;
}

/// Reads the AI's JSON, e.g. {"crop":"Tomato","town":"Leon","quantity":10,
/// "sort":"price"}. Unknown crops and towns are dropped, so the AI can't
/// make the app search for something we don't have. Returns null when the
/// text is not usable JSON.
SearchQuery? parseSearchQuery(String text) {
  try {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final data = jsonDecode(text.substring(start, end + 1));
    if (data is! Map) return null;
    return SearchQuery(
      crop: matchCrop(data['crop'] as String?),
      town: matchTown(data['town'] as String?),
      quantity: clampQuantity(data['quantity']),
      sort: switch (data['sort']) {
        'available' => SearchSort.available,
        'newest' => SearchSort.newest,
        _ => SearchSort.price,
      },
    );
  } catch (_) {
    return null;
  }
}

/// The amount in a question like "pechay 10 kg" or "5 kilos", or null.
double? quantityIn(String text) {
  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*(kg|kilo|kilos|bundle|sack|piece|pcs)?',
    caseSensitive: false,
  ).firstMatch(text);
  return match == null ? null : clampQuantity(match.group(1));
}

/// True when the question asks for zero or a negative amount.
bool asksZeroOrLess(String text) => RegExp(
  r'(^|\s)-\s*\d|(^|[^\d.])0+(\.0+)?\s*(kg|kilo|bundle|sack|piece)',
  caseSensitive: false,
).hasMatch(text);

/// How many letters must change to turn [a] into [b] (edit distance).
/// Swapping two letters next to each other ("prcie") counts as one.
int editDistance(String a, String b) {
  final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = [
        d[i - 1][j] + 1, // remove a letter
        d[i][j - 1] + 1, // add a letter
        d[i - 1][j - 1] + cost, // change a letter
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        best = best < d[i - 2][j - 2] + 1 ? best : d[i - 2][j - 2] + 1;
      }
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}

/// The first of our 71 crops named in [lower] (lowercase text), by name
/// or local name. Small typos in longer words are forgiven ("tomatoe"
/// finds Tomato).
String? cropInText(String lower) {
  for (final info in kCropCatalog) {
    final names = [info.name, ...info.localNames].map((n) => n.toLowerCase());
    if (names.any((n) => RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(lower))) {
      return info.name;
    }
  }
  final words = RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!);
  for (final word in words.where((w) => w.length >= 5)) {
    for (final info in kCropCatalog) {
      for (final name in [info.name, ...info.localNames]) {
        final n = name.toLowerCase();
        if (n.contains(' ') || (n.length - word.length).abs() > 1) continue;
        if (editDistance(word, n) <= (n.length >= 8 ? 2 : 1)) return info.name;
      }
    }
  }
  return null;
}

/// True for "what is available near me?"-style questions that may list
/// every crop. Other searches must name a crop we know.
bool isGeneralSearch(String text) => RegExp(
  r'available|anything|everything|what.*(sale|sell)|near me|all crops|'
  r'ano ang|unsa|lahat',
).hasMatch(text.toLowerCase());

/// The search without AI: finds a known crop and town in the words.
SearchQuery keywordQuery(String text) {
  final lower = text.toLowerCase();
  final crop = cropInText(lower);
  String? town;
  for (final t in kTowns) {
    if (lower.contains(t.toLowerCase())) {
      town = t;
      break;
    }
  }
  final sort = RegExp(r'most|biggest|largest|available|stock').hasMatch(lower)
      ? SearchSort.available
      : RegExp(r'new|latest|fresh').hasMatch(lower)
      ? SearchSort.newest
      : SearchSort.price;
  return SearchQuery(
    crop: crop,
    town: town,
    quantity: quantityIn(text),
    sort: sort,
  );
}

/// Up to [limit] listings that match [query] and still have stock, sorted.
/// When the buyer said an amount, listings with enough stock come first.
List<Listing> searchListings(
  List<Listing> listings,
  SearchQuery query, {
  int limit = 5,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final found = listings.where((l) {
    if (!l.isActive || l.availableAt(at) <= 0) return false;
    if (query.crop != null && l.crop != query.crop) return false;
    if (query.town != null && l.town != query.town) return false;
    return true;
  }).toList();
  found.sort((a, b) {
    final qty = query.quantity;
    if (qty != null) {
      final aEnough = a.availableAt(at) >= qty,
          bEnough = b.availableAt(at) >= qty;
      if (aEnough != bEnough) return aEnough ? -1 : 1;
    }
    return switch (query.sort) {
      SearchSort.price => a.price.compareTo(b.price),
      SearchSort.available => b.availableAt(at).compareTo(a.availableAt(at)),
      SearchSort.newest => b.createdAt.compareTo(a.createdAt),
    };
  });
  return found.take(limit).toList();
}

// -------------------------------------------------------- intent and data

/// Words the assistant looks for. A typed word that is close to one of
/// these ("prcie", "chepest", "webiste") or that hides one inside it
/// ("hteprices") is read as that word, so small typos don't matter.
const List<String> kAssistantWords = [
  'price',
  'prices',
  'cheapest',
  'expensive',
  'highest',
  'lowest',
  'compare',
  'website',
  'explain',
  'request',
  'reserved',
  'available',
  'vegetables',
  'vegetable',
  'fruits',
  'changed',
  'change',
  'month',
  'total',
  'order',
  'orders',
  'follow',
  'expired',
  'agosugnayan',
];

/// The question in lowercase, with typos of [kAssistantWords] fixed.
String normalizeQuestion(String text) {
  final lower = text.toLowerCase();
  return lower.replaceAllMapped(RegExp(r'[a-z]{4,}'), (match) {
    final word = match.group(0)!;
    if (kAssistantWords.contains(word)) return word;
    for (final known in kAssistantWords) {
      if (known.length < 5) continue;
      // "hteprices" -> "the prices": the word hides a known word.
      if (word.length > known.length && word.endsWith(known)) {
        return '${word.substring(0, word.length - known.length)} $known';
      }
      final limit = known.length >= 7 ? 2 : 1;
      if ((word.length - known.length).abs() <= limit &&
          editDistance(word, known) <= limit) {
        return known;
      }
    }
    return word;
  });
}

/// Every one of our crops named in [lower], in the order they appear.
List<String> cropsInText(String lower) {
  final found = <(int, String)>[];
  for (final info in kCropCatalog) {
    for (final name in [info.name, ...info.localNames]) {
      final match = RegExp('\\b${RegExp.escape(name.toLowerCase())}\\b')
          .firstMatch(lower);
      if (match != null) {
        found.add((match.start, info.name));
        break;
      }
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) f.$2];
}

/// Guesses what kind of question [text] is, using the page as a hint.
/// Returns null when it can't tell (then the AI is asked to classify it).
/// The order matters: app data first (so numbers come from the app),
/// then general chat, then how-to help.
AssistantIntent? detectIntent(String text, AssistantPage page) {
  final lower = normalizeQuestion(text);
  bool has(String pattern) => RegExp(pattern).hasMatch(lower);
  // Things the assistant must not do are answered by the app itself.
  if (outOfScopeReply(text) != null) return AssistantIntent.outOfScope;
  final crop = keywordQuery(lower).crop;
  final crops = cropsInText(lower);
  final onItem = page.listing != null || page.order != null;
  final priceWords = has(
    r'\b(price|prices|fair|how much|total|magkano|pila|presyo|cheap|'
    r'cheapest|expensive|mahal|barato|cost)\b',
  );

  // "What is this website?", "ano ito?", "unsa ni nga website?"
  if (has(
    r'what is (this|agosugnayan|the app)|what.s this|about (this|the) '
    r'(app|website|site)|explain (this|the) (app|website|site)|'
    r'(tell me|talk) about (this|the) (app|website|site)|how does (this|it|'
    r'the app) work|\bano (ito|ba ito|ang agosugnayan)\b|\bunsa (ni|ang)\b|'
    r'para saan|what can you do|who are you|this (website|app|site)\b|'
    r'\bagosugnayan\b',
  )) {
    return AssistantIntent.about;
  }
  if (crops.length >= 2 && has(r'\b(compare|vs|versus|or|and|kag|ug|at)\b')) {
    return AssistantIntent.compare;
  }
  if (crop == null &&
      has(r'changed|change since|went (up|down)|last month|tumaas|bumaba')) {
    return AssistantIntent.changes;
  }
  // "top 3 prices", "cheapest fruit", "pinakamahal nga prutas"
  if (crop == null &&
      has(
        r'\btop\b|highest|lowest|cheapest|expensive|pinakamahal|'
        r'pinakamura|barato|mahal|presyo',
      ) &&
      has(
        r'price|crop|vegetable|fruit|prutas|gulay|utan|bunga|leafy|'
        r'root|bean|condiment|\btop\b|pinaka',
      )) {
    return AssistantIntent.ranking;
  }
  // A crop "in the Market": real listings, not the PSA reference.
  // "Do you have rice?" is a search too (it then says rice is not one of
  // our crops).
  if (has(r'in the market|for sale|listing|do you have|meron|may .* ba\b')) {
    return AssistantIntent.search;
  }
  if (crop != null &&
      has(
        r'\b(find|cheapest|search|available|near|where|show|buy)\b|looking for',
      )) {
    return AssistantIntent.search;
  }
  // "pila ang kamatis sa Leon?": a crop with a town (or asked on the
  // Market) means the farmers' asking prices, so search the listings.
  if (crop != null &&
      priceWords &&
      (keywordQuery(lower).town != null ||
          page.screen == AssistantScreen.market)) {
    return AssistantIntent.search;
  }
  // Totals for the listing or order on the page.
  if (onItem &&
      has(r'how much for|total|\bfor \d|\d+\s*(kg|kilo)|magkano ang \d')) {
    return AssistantIntent.offerMath;
  }
  if (crop != null && has(r'going up|trend|rising|falling|next week')) {
    return AssistantIntent.trend;
  }
  // Price questions about a crop (named, or the one on the page). Mixed
  // questions ("is 45 fair and how do I store it?") also come here; the
  // answer then shows the general label too.
  if (priceWords && (crop != null || page.pageCrop != null)) {
    return AssistantIntent.priceCheck;
  }
  // "How much is rice?": a price for a crop we don't have. The price
  // path then says honestly that there is no PSA record.
  if (has(r'how much is|price of|presyo sang|presyo ng|magkano ang')) {
    return AssistantIntent.priceCheck;
  }
  // Food, storage, cooking, health basics and small talk: general chat.
  if (has(
    r'\b(store|storage|keep (it|them)|fresh longer|cook|recipe|nutrition|'
    r'vitamin|healthy|safe to eat|diabetes|difference between|joke|hello|'
    r'hi|hey|kumusta|musta|thank|thanks|salamat|bye|good (morning|'
    r'afternoon|evening))\b',
  )) {
    return AssistantIntent.general;
  }
  if (has(r'\b(reserved|status|waiting)\b|offer mean|what does .* mean')) {
    return page.order != null
        ? AssistantIntent.orderStatus
        : AssistantIntent.howTo;
  }
  if (has(
    r'\bhow (do|can|to|does)\b|\bwhat is\b.*\b(order|request|follow)|'
    r'\bwhere (do|can)\b|\bexpired?\b|\bfollow|\bpaano\b',
  )) {
    return AssistantIntent.howTo;
  }
  if (has(r'going up|trend|rising|falling|tumaas|bumaba')) {
    return AssistantIntent.trend;
  }
  if (has(r'\b(find|search|available|near|where|show|looking for|buy)\b')) {
    return AssistantIntent.search;
  }
  if (crop != null) return AssistantIntent.search;
  return null; // not sure: the service checks the FAQ, then asks the AI
}

/// The buyer's language, from common words: "Hiligaynon", "Filipino" or
/// "English". The prompt then says exactly which one to answer in, so
/// the AI doesn't switch language on its own.
String replyLanguage(String text) {
  final words = RegExp(r"[a-z']+")
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .toSet();
  const hiligaynon = {
    'pila',
    'sang',
    'subong',
    'gid',
    'kag',
    'nga',
    'unsa',
    'diin',
    'bala',
    'ini',
    'ari',
    'man',
    'utan',
    'baligya',
    'presyo',
    'salamat',
    'musta',
    'gusto',
    'ko',
    'ka',
    'ni',
  };
  const filipino = {
    'magkano',
    'po',
    'ano',
    'ito',
    'ba',
    'ng',
    'mga',
    'saan',
    'paano',
    'yung',
    'natin',
    'ang',
    'gulay',
    'mura',
    'kumusta',
    'ako',
  };
  final hil = words.intersection(hiligaynon).length;
  final fil = words.intersection(filipino).length;
  if (hil == 0 && fil == 0) return 'English';
  // Words both languages share count for both; Hiligaynon-only words
  // (pila, sang, gid, kag, nga, subong) decide.
  return hil >= fil ? 'Hiligaynon' : 'Filipino';
}

/// True when a data question also asks something general, like "is 45
/// fair for tomato AND how do I store it?" (the answer then shows both
/// labels).
bool hasGeneralPart(String text) => RegExp(
  r'\b(store|storage|keep (it|them)|cook|recipe|nutrition|vitamin|healthy|'
  r'season|grow|plant|difference between|what is a)\b',
).hasMatch(text.toLowerCase());

/// Reads the AI's one-word classification, e.g. "ranking". Anything else
/// (unknown words, "outOfScope") becomes null: the app then gives its
/// friendly "I can't help with that" answer.
AssistantIntent? parseIntent(String text) {
  final word = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  for (final intent in AssistantIntent.values) {
    if (intent.name.toLowerCase() == word) {
      // "outOfScope" now means: just chat (general knowledge).
      return intent == AssistantIntent.outOfScope
          ? AssistantIntent.general
          : intent;
    }
  }
  return null;
}

/// A fixed answer (no AI) for questions the assistant must not handle:
/// acting for the buyer, health advice, personal data, attempts to change
/// its rules, and questions with no words. Null for normal questions.
String? outOfScopeReply(String text) {
  final lower = text.toLowerCase().trim();
  bool has(String pattern) => RegExp(pattern).hasMatch(lower);
  if (!RegExp(r'[a-z0-9]').hasMatch(lower)) {
    return 'Please type your question in words, like "Find the cheapest '
        'tomato" or "How much for 5 kg?".';
  }
  if (has(
    r'ignore (all|the|your|previous|any)\b|system prompt|your (rules|'
    r'instructions)|pretend|jailbreak|developer mode',
  )) {
    return "I can't do that. I can help with prices, finding crops, totals "
        'and how orders work.';
  }
  if (has(
    r'phone|contact (number|details)|e-?mail|home address|all users|'
    r'list (of )?users|password|user id',
  )) {
    return "I can't share anyone's contact details. Use \"Message farmer\" "
        'to talk with a farmer inside the app.';
  }
  if (has(r'discount|tawad|haggle|lower (the|your) price|bawas')) {
    return "I can't change prices or give discounts. You can ask the farmer "
        'politely in Messages.';
  }
  if (has(
    r'\b(buy|order|reserve|accept|decline|cancel)\b.*\bfor me\b|'
    r'^(please )?(accept|decline|buy)\b|\bsend (a |the )?message|'
    r'\bmessage the farmer\b',
  )) {
    return "I can't buy, accept, decline or send messages for you. Use the "
        'buttons on the page: "Request to buy" on a listing, or Accept and '
        'Decline on an offer card.';
  }
  return null;
}

/// Cuts [text] after its 5th sentence, so answers stay short.
String limitSentences(String text, {int max = 5}) {
  final ends = RegExp(r'[.!?](\s|$)').allMatches(text).toList();
  if (ends.length <= max) return text.trim();
  return text.substring(0, ends[max - 1].start + 1).trim();
}

/// Farmer-written text (titles, descriptions, notes) is data, not orders
/// for the AI: we cut it short and remove characters that could fake the
/// start or end of our data block.
String cleanUntrusted(String text, {int max = 120}) {
  final flat = text
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'[<>{}\[\]`]'), '');
  return flat.length <= max ? flat.trim() : '${flat.substring(0, max).trim()}…';
}

/// 20.0 becomes 20 (so the AI writes "20 kg", not "20.0 kg"); 12.5 stays.
num wholeIfWhole(double value) =>
    value == value.roundToDouble() ? value.toInt() : value;

/// A listing as facts for the AI: only what the Market already shows.
/// No ids, no emails, no phone numbers.
Map<String, dynamic> listingFacts(Listing l, {DateTime? now}) => {
  'title': cleanUntrusted(l.headline, max: 40),
  'crop': l.crop,
  'pricePerUnit': l.price,
  'unit': l.unit,
  'available': wholeIfWhole(l.availableAt(now ?? DateTime.now())),
  'town': l.town,
  'farmer': cleanUntrusted(l.farmerName, max: 40),
};

/// The facts as compact JSON, cut to about 600 tokens (~2,400 characters).
String factsJson(Map<String, dynamic> facts, {int maxChars = 2400}) {
  final text = jsonEncode(facts);
  return text.length <= maxChars ? text : text.substring(0, maxChars);
}

// ----------------------------------------------------------------- limits

/// Keeps the assistant inside Gemini's free tier: one question at a
/// time, 3 seconds between questions and 20 questions per session.
class AssistantLimits {
  AssistantLimits({
    this.cooldown = const Duration(seconds: 3),
    this.maxPerSession = 40,
  });

  final Duration cooldown;
  final int maxPerSession;
  bool isBusy = false;
  DateTime? _lastAsked;
  int asked = 0;

  /// Null when the buyer may ask now; otherwise the friendly reason.
  /// After [maxPerSession] questions the buyer can still ask: the app then
  /// answers with its own facts only (see [aiAllowed]).
  String? whyNot(DateTime now) {
    if (isBusy) return 'Please wait for the answer to the last question.';
    final last = _lastAsked;
    if (last != null && now.difference(last) < cooldown) {
      return 'Please wait a few seconds before the next question.';
    }
    return null;
  }

  /// True when the AI may be used for this question (else: facts only).
  bool get aiAllowed => asked < maxPerSession;

  /// Call when a question starts; [usesAi] counts it toward the limit.
  void started(DateTime now, {bool usesAi = true}) {
    isBusy = true;
    _lastAsked = now;
    if (usesAi) asked++;
  }

  void finished() => isBusy = false;

  void reset() {
    asked = 0;
    _lastAsked = null;
    isBusy = false;
  }
}
