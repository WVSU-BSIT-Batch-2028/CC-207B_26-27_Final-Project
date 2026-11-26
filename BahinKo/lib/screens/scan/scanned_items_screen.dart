/// Shows the items found by the receipt scanner (or typed manually).
///
/// Stand-in for BahinKo's Assign Items screen: the bill-splitting step is
/// not part of this project, so this screen just lists what was scanned.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/expense.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/services/receipt_scanner.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';

class ScannedItems extends StatelessWidget {
  /// Pass [scan] (from the scanner) or [receiptItems] (manual entry).
  const ScannedItems({
    super.key,
    this.scan,
    this.receiptItems,
    this.storeName,
    this.groupId,
  });

  final ScanResult? scan;
  final List<ReceiptLineItem>? receiptItems;
  final String? storeName;
  final String? groupId;

  List<ExpenseItem> get _items =>
      scan?.items ??
      [
        for (final i in receiptItems ?? const <ReceiptLineItem>[])
          ExpenseItem(name: i.name, amountCents: i.amountInCents),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = items.fold<int>(0, (sum, i) => sum + i.amountCents);
    final warning = scan?.warning;

    return AppPage(
      scan?.storeName ?? storeName ?? 'Scanned Receipt',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warning != null) ...[
            InfoBanner(warning),
            const SizedBox(height: 12),
          ],
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: item.needsReview
                  ? const Text('Needs review', style: TextStyle(color: orange))
                  : null,
              trailing: Text(formatMoney(item.amountCents)),
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: Text(
              formatMoney(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Btn('Done', () => Navigator.of(context).pop(items)),
        ],
      ),
    );
  }
}
