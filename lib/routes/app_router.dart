import 'package:flutter/widgets.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/screens/driver/driver_shell.dart';
import 'package:websupark/screens/guard/guard_flow_screen.dart';

/// Connects each route name (from AppRoutes) to the screen it opens.
/// Head-security routes are added in the next step.
class AppRouter {
  AppRouter._();

  static final Map<String, WidgetBuilder> routes = {
    // Driver: all five tab names open the same shell, on a different tab.
    AppRoutes.driverHome: (_) => const DriverShell(initialIndex: 0),
    AppRoutes.driverAssignment: (_) => const DriverShell(initialIndex: 1),
    AppRoutes.driverAlerts: (_) => const DriverShell(initialIndex: 2),
    AppRoutes.driverViolations: (_) => const DriverShell(initialIndex: 3),
    AppRoutes.driverVehicle: (_) => const DriverShell(initialIndex: 4),

    // Guard: a chain of screens S1 to S6. Each temporary button
    // points to the next screen in the prototype flow.
    AppRoutes.guardConsole: (_) => const GuardFlowScreen(
          title: 'Patrol Console',
          screenCode: 'S1',
          nextRoute: AppRoutes.guardScan,
          nextLabel: 'Scan Vehicle Pass',
        ),
    AppRoutes.guardScan: (_) => const GuardFlowScreen(
          title: 'Scan Vehicle Pass',
          screenCode: 'S2',
          nextRoute: AppRoutes.guardVehicleRecord,
          nextLabel: 'Open Vehicle Record',
        ),
    AppRoutes.guardVehicleRecord: (_) => const GuardFlowScreen(
          title: 'Vehicle Record',
          screenCode: 'S3',
          nextRoute: AppRoutes.guardVerifyParking,
          nextLabel: 'Verify Parking Location',
        ),
    AppRoutes.guardVerifyParking: (_) => const GuardFlowScreen(
          title: 'Verify Parking',
          screenCode: 'S4',
          nextRoute: AppRoutes.guardReportViolation,
          nextLabel: 'Report Violation',
        ),
    AppRoutes.guardReportViolation: (_) => const GuardFlowScreen(
          title: 'Report Violation',
          screenCode: 'S5',
          nextRoute: AppRoutes.guardReportSubmitted,
          nextLabel: 'Submit Violation',
        ),
    AppRoutes.guardReportSubmitted: (_) => const GuardFlowScreen(
          title: 'Report Submitted',
          screenCode: 'S6',
          nextRoute: AppRoutes.guardConsole,
          nextLabel: 'Return to Patrol',
        ),
  };
}