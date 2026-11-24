import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stock_alert_item.dart';
import '../services/stock_alerts_service.dart';
import 'inventory_providers.dart';
import 'session_providers.dart';

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

// Asynchronously loads all categorized stock alerts.
// Automatically recomputes whenever inventoryProvider updates or reloads,
// providing instant realtime reactivity without needing a manual page refresh.
final stockAlertsProvider =
    FutureProvider.autoDispose<Map<StockAlertType, List<StockAlertItem>>>((ref) async {
  restoreSessionIfNeeded(
    currentSession: ref.read(sessionProvider),
    setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
  );
  ref.watch(sessionProvider);

  // Watch inventoryProvider so any local or realtime inventory change
  // immediately recalculates stock alerts across all tabs and badges.
  final inventoryAsync = ref.watch(inventoryProvider);
  if (inventoryAsync.hasValue) {
    return StockAlertsService.computeAlertsFromInventory(inventoryAsync.value!);
  }

  final service = ref.watch(stockAlertsServiceProvider);
  return service.loadStockAlerts();
});
