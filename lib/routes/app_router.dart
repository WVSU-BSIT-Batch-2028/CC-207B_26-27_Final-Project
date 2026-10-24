import 'package:flutter/widgets.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/screens/driver/driver_shell.dart';

/// Connects each route name (from AppRoutes) to the screen it opens.
/// Guard and head-security routes are added in the next steps.
class AppRouter {
  AppRouter._();

  static final Map<String, WidgetBuilder> routes = {
    // All five driver tab names open the same shell, on a different tab.
    AppRoutes.driverHome: (_) => const DriverShell(initialIndex: 0),
    AppRoutes.driverAssignment: (_) => const DriverShell(initialIndex: 1),
    AppRoutes.driverAlerts: (_) => const DriverShell(initialIndex: 2),
    AppRoutes.driverViolations: (_) => const DriverShell(initialIndex: 3),
    AppRoutes.driverVehicle: (_) => const DriverShell(initialIndex: 4),
  };
}
