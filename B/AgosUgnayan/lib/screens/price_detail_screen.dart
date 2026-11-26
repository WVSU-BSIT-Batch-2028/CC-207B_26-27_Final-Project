// F6 Reference Prices: one crop's price over the last 12 months, as a line
// chart (fl_chart) and as a list.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../services/assistant_controller.dart';

import '../models/price_record.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/crop_image.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';

/// Price history of [crop]. [history] is sorted oldest month first.
class PriceDetailScreen extends StatelessWidget {
  const PriceDetailScreen({
    super.key,
    required this.crop,
    required this.history,
    this.isOlder = false,
  });

  final String crop;
  final List<PriceRecord> history;

  /// True when this crop's newest price is from before the newest month
  /// of all crops. The page then says so, so it isn't read as current.
  final bool isOlder;

  @override
  Widget build(BuildContext context) {
    // Tells the buyer AI assistant which crop and prices are open.
    return AssistantScope(
      page: AssistantPage(
        AssistantScreen.priceDetail,
        crop: crop,
        history: history,
      ),
      child: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext context) {
    final latest = history.last;
    final prices = [for (final record in history) record.price];
    final lowest = prices.reduce((a, b) => a < b ? a : b);
    final highest = prices.reduce((a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: Text(crop)),
      body: ResponsiveBody(
        maxWidth: AppSizes.maxFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            CropHero(crop: crop),
            const SizedBox(height: AppSizes.fieldGap),
            PageHeader(
              eyebrow: '$kPriceSource · ${formatMonthKey(latest.month)}',
              title: crop,
              lead: 'Reference farmgate price per kg.',
            ),
            if (isOlder) ...[
              const SizedBox(height: 10),
              NoticeBox(
                kind: NoticeKind.warning,
                message:
                    'Older price: the newest PSA price for $crop is from '
                    '${formatMonthKey(latest.month)}. Newer months have no '
                    'price for it yet.',
              ),
            ],
            const SizedBox(height: AppSizes.fieldGap),
            // Three tiles: this month, lowest and highest (website .tiles).
            Row(
              children: [
                Expanded(
                  child: _Tile(label: 'This month', price: latest.price),
                ),
                const SizedBox(width: AppSizes.small),
                Expanded(
                  child: _Tile(label: 'Lowest', price: lowest),
                ),
                const SizedBox(width: AppSizes.small),
                Expanded(
                  child: _Tile(label: 'Highest', price: highest),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sectionGap),
            const SectionTitle('Last 12 months'),
            const SizedBox(height: AppSizes.small),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: SizedBox(height: 220, child: _buildChart()),
              ),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            const SectionTitle('Month by month'),
            const SizedBox(height: AppSizes.small),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Newest month first in the list.
                  for (final record in history.reversed) ...[
                    if (record != history.last) const Divider(),
                    ListTile(
                      dense: true,
                      title: Text(
                        formatMonthKey(record.month),
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Text(
                        '${formatPeso(record.price)}/kg',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            // A few sentences about the crop from Wikipedia (hidden offline).
            CropAbout(crop: crop),
          ],
        ),
      ),
    );
  }

  /// A line chart: x = month number (0, 1, 2…), y = price.
  Widget _buildChart() {
    final spots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].price),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              // Skip the label at the very top: it is an odd number that
              // overlaps the line above it.
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              // Show the month's short name, e.g. "Aug", under each point.
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= history.length) {
                  return const SizedBox.shrink();
                }
                final label = formatMonthKey(history[index].month);
                return Text(
                  label.substring(0, 3),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

/// A small white tile with a label and a price, e.g. "Lowest ₱38.00".
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.price});

  final String label;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.meta),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatPeso(price),
                style: AppTextStyles.price.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
