import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stock_alert_item.dart';
import '../services/stock_alerts_service.dart';

// Provider for the StockAlertsService
final stockAlertsServiceProvider = Provider<StockAlertsService>((ref) {
  return StockAlertsService();
});

// Currently selected alert tab notifier
class SelectedAlertTabNotifier extends Notifier<StockAlertType> {
  @override
  StockAlertType build() => StockAlertType.lowStock;

  void selectTab(StockAlertType tab) => state = tab;
}

final selectedAlertTabProvider =
    NotifierProvider<SelectedAlertTabNotifier, StockAlertType>(SelectedAlertTabNotifier.new);

// Asynchronously loads all categorized stock alerts
final stockAlertsProvider =
    FutureProvider.autoDispose<Map<StockAlertType, List<StockAlertItem>>>((ref) async {
  final service = ref.watch(stockAlertsServiceProvider);
  return service.loadStockAlerts();
});
