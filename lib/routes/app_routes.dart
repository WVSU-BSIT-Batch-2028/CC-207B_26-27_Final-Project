/// Every screen name in WEBSUPARK, in one place.
/// Rule for the whole team: never type a route string by hand.
/// Always use AppRoutes.something, so a typo becomes a compile error
/// instead of a button that silently goes nowhere.
class AppRoutes {
  AppRoutes._();

  // Entry point of the app.
  static const String root = '/';

  // Driver interface (mobile). The first five are the bottom-navigation tabs.
  static const String driverHome = '/driver/home';
  static const String driverAssignment = '/driver/assignment';
  static const String driverAlerts = '/driver/alerts';
  static const String driverViolations = '/driver/violations';
  static const String driverVehicle = '/driver/vehicle';
  // Vehicle pass renewal: 3 steps, then a confirmation screen.
  static const String driverRenewalPayment = '/driver/renewal/payment';
  static const String driverRenewalDetails = '/driver/renewal/details';
  static const String driverRenewalReview = '/driver/renewal/review';
  static const String driverRenewalSubmitted = '/driver/renewal/submitted';

  // Security guard interface (mobile).
  static const String guardConsole = '/guard/console';
  static const String guardScan = '/guard/scan';
  static const String guardVehicleRecord = '/guard/vehicle-record';
  static const String guardVerifyParking = '/guard/verify-parking';
  static const String guardReportViolation = '/guard/report-violation';
  static const String guardReportSubmitted = '/guard/report-submitted';

  // Head security interface (desktop). These are the sidebar pages.
  // Entrance Monitoring is intentionally left out (hidden for now).
  static const String headOverview = '/head/overview';
  static const String headVehicles = '/head/vehicles';
  static const String headParking = '/head/parking';
  static const String headViolations = '/head/violations';
  static const String headYellowPass = '/head/yellow-pass';
  static const String headOutsideVehicles = '/head/outside-vehicles';
}