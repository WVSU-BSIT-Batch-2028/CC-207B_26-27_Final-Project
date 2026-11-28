import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/weather.dart';
import 'package:littlesteps/screens/account/settings_screen.dart';
import 'package:littlesteps/screens/ai/ai_suggestions_screen.dart';
import 'package:littlesteps/screens/today/today_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

class _NoopAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> refreshToken(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class _CapturingCatalogService extends CatalogService {
  _CapturingCatalogService({required this.hint})
    : super(apiClient: ApiClient());

  final WeatherHint hint;
  double? lastLatitude;
  double? lastLongitude;
  int callCount = 0;

  @override
  Future<WeatherHint> getWeather({
    double latitude = 10.72,
    double longitude = 122.56,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return hint;
  }
}

void main() {
  group('WeatherLocation and WeatherHint', () {
    test('resolves Philippine cities case-insensitively', () {
      expect(WeatherLocation.philippinesCities.length, 5);
      expect(
        WeatherLocation.byName('manila'),
        const WeatherLocation(
          name: 'Manila',
          latitude: 14.5995,
          longitude: 120.9842,
        ),
      );
      expect(WeatherLocation.byName(''), isNull);
      expect(WeatherLocation.byName('Unknown'), isNull);
    });

    test('detects rainy WMO conditions and high rain chance', () {
      const rainyHint = WeatherHint(
        condition: 'showers',
        rainChance: 30,
        heatFlag: false,
        suggestedSetting: 'indoor',
        hint: 'Rain likely this afternoon · Indoor ideas',
        attribution: 'Weather data by Open-Meteo.com',
      );
      const sunnyHint = WeatherHint(
        condition: 'clear',
        rainChance: 10,
        heatFlag: false,
        suggestedSetting: 'outdoor',
        hint: 'Good weather for outdoor play · Outdoor ideas',
        attribution: 'Weather data by Open-Meteo.com',
      );
      const highChanceCloudy = WeatherHint(
        condition: 'cloudy',
        rainChance: 65,
        heatFlag: false,
        suggestedSetting: 'indoor',
        hint: 'Rain likely this afternoon · Indoor ideas',
        attribution: 'Weather data by Open-Meteo.com',
      );

      expect(rainyHint.isRainy, isTrue);
      expect(sunnyHint.isRainy, isFalse);
      expect(highChanceCloudy.isRainy, isTrue);
      expect(rainyHint.isIndoorSuggested, isTrue);
      expect(sunnyHint.isOutdoorSuggested, isTrue);
      expect(
        rainyHint.displayMessage(stripActionSuffix: true),
        'Rain likely this afternoon',
      );
      expect(
        sunnyHint.displayMessage(stripActionSuffix: true),
        'Good weather for outdoor play',
      );
    });
  });

  group('SettingsScreen weather selector', () {
    testWidgets('updates AuthSessionState weatherLocation when city changes', (
      tester,
    ) async {
      final session = AuthSessionState(authService: _NoopAuthService());
      expect(session.weatherLocation, WeatherLocation.iloiloCity);

      await tester.pumpWidget(
        AuthScope(
          sessionState: session,
          apiClient: ApiClient(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsScreen(email: 'caregiver@example.com'),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_weather_city_dropdown')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Weather for activity ideas'), findsOneWidget);
      expect(find.textContaining('Open-Meteo.com'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('settings_weather_city_dropdown')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manila').last);
      await tester.pumpAndSettle();
      expect(session.weatherLocation?.name, 'Manila');

      await tester.tap(
        find.byKey(const ValueKey('settings_weather_city_dropdown')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Off (no weather hints)').last);
      await tester.pumpAndSettle();
      expect(session.weatherLocation, isNull);
    });
  });

  group('AiSuggestionsScreen Open-Meteo integration', () {
    testWidgets('uses selected city coordinates and shows Open-Meteo credit', (
      tester,
    ) async {
      final session = AuthSessionState(authService: _NoopAuthService());
      session.setWeatherLocation(WeatherLocation.byName('Baguio'));
      final catalog = _CapturingCatalogService(
        hint: const WeatherHint(
          condition: 'rain',
          rainChance: 80,
          heatFlag: false,
          suggestedSetting: 'indoor',
          hint: 'Rain likely this afternoon · Indoor ideas',
          attribution: 'Weather data by Open-Meteo.com',
        ),
      );

      await tester.pumpWidget(
        AuthScope(
          sessionState: session,
          apiClient: ApiClient(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: AiSuggestionsScreen(catalogService: catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.callCount, 1);
      expect(catalog.lastLatitude, closeTo(16.4023, 0.001));
      expect(catalog.lastLongitude, closeTo(120.5960, 0.001));
      expect(
        find.text('Rain likely this afternoon · Indoor ideas'),
        findsOneWidget,
      );
      expect(
        find.text('Baguio · Weather data by Open-Meteo.com'),
        findsOneWidget,
      );
    });

    testWidgets('skips weather fetch when weather hints are turned off', (
      tester,
    ) async {
      final session = AuthSessionState(authService: _NoopAuthService());
      session.setWeatherLocation(null);
      final catalog = _CapturingCatalogService(
        hint: const WeatherHint(
          condition: 'clear',
          rainChance: 5,
          heatFlag: false,
          suggestedSetting: 'outdoor',
          hint: 'Good weather for outdoor play · Outdoor ideas',
          attribution: 'Weather data by Open-Meteo.com',
        ),
      );

      await tester.pumpWidget(
        AuthScope(
          sessionState: session,
          apiClient: ApiClient(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: AiSuggestionsScreen(catalogService: catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.callCount, 0);
      expect(find.textContaining('Open-Meteo.com'), findsNothing);
    });
  });

  group('TodayScreen weather location refresh', () {
    testWidgets(
      'refreshes weather hint when Settings city changes and clears when off',
      (tester) async {
        final session = AuthSessionState(authService: _NoopAuthService());
        final catalog = _CapturingCatalogService(
          hint: const WeatherHint(
            condition: 'clear',
            rainChance: 10,
            heatFlag: false,
            suggestedSetting: 'outdoor',
            hint: 'Good weather for outdoor play · Outdoor ideas',
            attribution: 'Weather data by Open-Meteo.com',
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            sessionState: session,
            apiClient: ApiClient(),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: TodayScreen(
                  initialState: TodayViewState.empty,
                  initialPlans: const [],
                  catalogService: catalog,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(catalog.callCount, 0);
        expect(find.textContaining('Outdoor ideas'), findsNothing);

        session.setWeatherLocation(WeatherLocation.byName('Manila'));
        await tester.pumpAndSettle();

        expect(catalog.callCount, 1);
        expect(catalog.lastLatitude, closeTo(14.5995, 0.001));
        expect(catalog.lastLongitude, closeTo(120.9842, 0.001));
        expect(find.text('Good weather for outdoor play'), findsOneWidget);
        expect(find.text('Find outdoor ideas'), findsOneWidget);

        session.setWeatherLocation(null);
        await tester.pumpAndSettle();

        expect(catalog.callCount, 1);
        expect(find.text('Good weather for outdoor play'), findsNothing);
        expect(find.text('Find outdoor ideas'), findsNothing);
      },
    );
  });
}
