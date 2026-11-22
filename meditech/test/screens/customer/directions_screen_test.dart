import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditech/screens/customer/pharmacy/directions_screen.dart';
import 'package:meditech/services/route_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';

class FakeRouteService extends Fake implements RouteService {
  @override
  Future<RouteResult> getDirections({
    required LatLng start,
    required LatLng end,
    String profile = 'driving-car',
  }) async {
    return const RouteResult(
      points: [
        LatLng(10.7202, 122.5621),
        LatLng(10.7000, 122.5500),
        LatLng(10.6950, 122.5450),
      ],
      distanceMeters: 3500,
      durationSeconds: 480,
    );
  }
}

void main() {
  late FakeRouteService fakeRouteService;
  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  setUp(() {
    fakeRouteService = FakeRouteService();

    // Stub Geolocator platform channel so widget tests immediately receive "denied"
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (MethodCall call) async {
          switch (call.method) {
            case 'isLocationServiceEnabled':
              return true;
            case 'checkPermission':
            case 'requestPermission':
              return 0; // LocationPermission.denied
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
  });

  Widget buildSubject({
    String pharmacyName = 'Mercury Drug',
    String branchName = 'Molo Plaza',
    String address = 'Molo Plaza, Iloilo City',
    LatLng destination = const LatLng(10.695, 122.545),
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: DirectionsScreen(
        pharmacyName: pharmacyName,
        branchName: branchName,
        address: address,
        destination: destination,
        routeService: fakeRouteService,
      ),
    );
  }

  Future<void> pumpUntilRouteReady(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('3.5 km').evaluate().isNotEmpty &&
          find.text('Change').evaluate().isNotEmpty) {
        break;
      }
    }
  }

  testWidgets(
    'renders pharmacy destination details and calculated route info',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await pumpUntilRouteReady(tester);

      // Verify AppBar
      expect(find.text('Directions'), findsOneWidget);

      // Verify Destination details in bottom card
      expect(find.text('Mercury Drug'), findsOneWidget);
      expect(find.text('Molo Plaza'), findsOneWidget);
      expect(find.text('Molo Plaza, Iloilo City'), findsOneWidget);

      // Verify formatted distance (3.5 km) and duration (~8 mins)
      expect(find.text('3.5 km'), findsOneWidget);
      expect(find.text('~8 mins'), findsOneWidget);

      // Verify fallback location-denied banner shows on headless/desktop test
      expect(
        find.text('Location denied. Using manual starting point.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping change origin opens landmarks selection dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await pumpUntilRouteReady(tester);

    // Tap the 'Change' button on the permission banner
    final changeText = find.text('Change');
    expect(changeText, findsOneWidget);
    final buttonFinder = find.ancestor(
      of: changeText,
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    if (buttonFinder.evaluate().isNotEmpty) {
      tester.widget<ButtonStyleButton>(buttonFinder.first).onPressed?.call();
    } else {
      await tester.tap(changeText);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify landmark bottom sheet appeared with preset landmarks
    expect(find.text('Select Starting Location'), findsOneWidget);
    expect(find.text('SM City Iloilo'), findsOneWidget);
    expect(find.text('Jaro Plaza'), findsOneWidget);
    expect(find.text('Iloilo City Hall'), findsOneWidget);
  });
}
