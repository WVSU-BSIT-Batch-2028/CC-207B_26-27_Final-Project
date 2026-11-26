// Price lists for the buyer assistant, worked out in plain Dart from the
// PSA prices we already loaded: "top 3 prices", "cheapest fruit",
// "compare tomato and cabbage", "what changed since last month". Prices
// from older months are never ranked as current: they are left out of the
// ranking and counted in a note instead.

import '../models/assistant.dart';
import '../models/price_record.dart';
import '../services/price_service.dart';
import 'constants.dart';
import 'format.dart';

/// Which way to sort a price list.
enum RankOrder { highest, lowest }

/// What the buyer asked for: how many, which way, which category.
class RankRequest {
  const RankRequest({
    this.count = 5,
    this.order = RankOrder.highest,
    this.categories = const [],
    this.orderWasSaid = true,
  });

  final int count; // 1 to 10
  final RankOrder order;
  final List<CropCategory> categories; // empty = all crops

  /// False when the buyer said "top 3" without "highest" or "cheapest":
  /// we then show the highest and say so.
  final bool orderWasSaid;
}

/// Reads "top 3", "cheapest fruit", "pinakamahal nga prutas", "top 5
/// vegetables" into a [RankRequest]. [lower] is the normalised question.
RankRequest rankRequestFrom(String lower) {
  final number = RegExp(r'\b(\d{1,2})\b').firstMatch(lower)?.group(1);
  final count = (int.tryParse(number ?? '') ?? 5).clamp(1, 10);
  final low = RegExp(
    r'cheap|lowest|least expensive|pinakamura|mura|barato|baratu',
  ).hasMatch(lower);
  final high = RegExp(r'highest|expensive|pinakamahal|mahal|priciest|most')
      .hasMatch(lower);
  return RankRequest(
    count: count,
    order: low ? RankOrder.lowest : RankOrder.highest,
    categories: categoriesIn(lower),
    orderWasSaid: low || high,
  );
}

/// The crop categories named in [lower]: "fruit(s)/prutas/bunga" are
/// fruits; "vegetable(s)/gulay/utan" are all the vegetable groups.
List<CropCategory> categoriesIn(String lower) {
  bool has(String pattern) => RegExp(pattern).hasMatch(lower);
  if (has(r'leafy|dahon')) return [CropCategory.leafyVegetables];
  if (has(r'root')) return [CropCategory.rootCrops];
  if (has(r'bean|legume|balatong')) return [CropCategory.beans];
  if (has(r'condiment|spice|rekado')) return [CropCategory.condiments];
  if (has(r'fruit vegetable')) return [CropCategory.fruitVegetables];
  if (has(r'fruit|prutas|bunga')) return [CropCategory.fruits];
  if (has(r'vegetable|veggie|gulay|utan')) {
    return CropCategory.values.where((c) => c != CropCategory.fruits).toList();
  }
  return const [];
}

/// The answer for a price list: rows for the Facts box and one sentence.
class PriceListAnswer {
  const PriceListAnswer(this.rows, this.sentence);

  final List<FactRow> rows;
  final String sentence;
}

/// The highest or lowest PSA prices, newest month only.
PriceListAnswer rankPrices(List<PriceRecord> records, RankRequest request) {
  final newest = PriceService.newestMonth(records);
  if (newest == null) {
    return const PriceListAnswer([], "I don't have any PSA prices loaded.");
  }
  final allowed = request.categories.isEmpty
      ? kCrops
      : [for (final c in request.categories) ...cropsIn(c)];
  final current = <PriceRecord>[];
  var older = 0;
  for (final crop in allowed) {
    final latest = PriceService.latestFor(crop, records);
    if (latest == null) continue;
    // An older month is not "now", so it can't be ranked with the rest.
    latest.month == newest ? current.add(latest) : older++;
  }
  current.sort(
    (a, b) => request.order == RankOrder.highest
        ? b.price.compareTo(a.price)
        : a.price.compareTo(b.price),
  );
  final shown = current.take(request.count).toList();
  final what = request.categories.length == 1
      ? request.categories.first.label.toLowerCase()
      : request.categories.isEmpty
      ? 'crops'
      : 'vegetables';
  final way = request.order == RankOrder.highest ? 'highest' : 'lowest';
  final rows = [
    for (final (i, r) in shown.indexed)
      FactRow('${i + 1}. ${r.crop}', '${formatPeso(r.price)}/kg'),
    FactRow('PSA month', formatMonthKey(newest)),
    if (older > 0)
      FactRow('Not ranked', '$older with only older prices (see Prices)'),
  ];
  final hint = request.orderWasSaid
      ? ''
      : ' Showing the highest prices. Say "cheapest" for the lowest.';
  return PriceListAnswer(
    rows,
    shown.isEmpty
        ? 'I found no current PSA prices for $what.'
        : 'Here are the ${shown.length} $way PSA farmgate prices for $what '
              '(${formatMonthKey(newest)}).$hint',
  );
}

/// Two (or more) crops side by side: newest PSA price and month.
PriceListAnswer comparePrices(List<String> crops, List<PriceRecord> records) {
  final rows = <FactRow>[];
  for (final crop in crops.take(4)) {
    final latest = PriceService.latestFor(crop, records);
    if (latest == null) {
      rows.add(FactRow(crop, 'No PSA price'));
      continue;
    }
    final older = PriceService.isOlderPrice(crop, records) ? ', older' : '';
    rows.add(
      FactRow(
        crop,
        '${formatPeso(latest.price)}/kg (${formatMonthKey(latest.month)}$older)',
      ),
    );
  }
  final prices = [
    for (final crop in crops.take(4))
      if (PriceService.latestFor(crop, records) case final r?) (crop, r.price),
  ];
  if (prices.length < 2) {
    return PriceListAnswer(rows, "I don't have PSA prices for both crops.");
  }
  prices.sort((a, b) => b.$2.compareTo(a.$2));
  final (topCrop, topPrice) = prices.first;
  final (lowCrop, lowPrice) = prices.last;
  return PriceListAnswer(
    rows,
    '$topCrop has the higher PSA farmgate price, '
    '${formatPeso(topPrice - lowPrice)}/kg more than $lowCrop.',
  );
}

/// The biggest price changes since the month before (only crops whose
/// two newest prices are in neighbouring months).
PriceListAnswer biggestChanges(
  List<PriceRecord> records, {
  int count = 5,
  List<CropCategory> categories = const [],
}) {
  final allowed = categories.isEmpty
      ? kCrops
      : [for (final c in categories) ...cropsIn(c)];
  final changes = <(String, double)>[
    for (final crop in allowed)
      if (PriceService.monthlyChange(crop, records) case final change?)
        if (change != 0) (crop, change),
  ]..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
  final shown = changes.take(count).toList();
  return PriceListAnswer(
    [
      for (final (crop, change) in shown)
        FactRow(
          crop,
          '${change > 0 ? '▲ up' : '▼ down'} ${formatPeso(change.abs())}/kg',
        ),
    ],
    shown.isEmpty
        ? 'No PSA price changed since the month before, in the months we have.'
        : 'These PSA prices changed the most since the month before.',
  );
}
