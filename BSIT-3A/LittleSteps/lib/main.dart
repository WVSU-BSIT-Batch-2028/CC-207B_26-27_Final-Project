import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'routing/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/auth_session_state.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_scope.dart';

/// Scroll behavior enabling touch, mouse, trackpad, and stylus drag gestures.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// Creates an [AppScrollBehavior].
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

void main() {
  AppConfig.validateForRelease();
  runApp(const LittleStepsApp());
}

/// The root application widget for LittleSteps.
class LittleStepsApp extends StatefulWidget {
  /// Creates a [LittleStepsApp].
  ///
  /// Optional [sessionState] and [apiClient] can be injected for testing.
  const LittleStepsApp({super.key, this.sessionState, this.apiClient});

  /// Injected session state for testing or custom configuration.
  final AuthSessionState? sessionState;

  /// Injected API client for testing or custom configuration.
  final ApiClient? apiClient;

  @override
  State<LittleStepsApp> createState() => _LittleStepsAppState();
}

class _LittleStepsAppState extends State<LittleStepsApp> {
  late final AuthSessionState _sessionState;
  late final ApiClient _apiClient;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _sessionState =
        widget.sessionState ??
        AuthSessionState(
          authService: FirebaseAuthRestService(),
          onClearCache: () => _apiClient.clearCache(),
        );

    _apiClient =
        widget.apiClient ??
        ApiClient(
          tokenProvider: () => _sessionState.idToken,
          onRefreshToken: () => _sessionState.refreshToken(),
          onSessionExpired: () {
            _sessionState.handleSessionExpired();
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
              AppRoutes.signedOut,
              (route) => false,
              arguments: 'Please sign in again to continue',
            );
          },
        );
  }

  @override
  void dispose() {
    if (widget.apiClient == null) {
      _apiClient.dispose();
    }
    if (widget.sessionState == null) {
      _sessionState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      sessionState: _sessionState,
      apiClient: _apiClient,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'LittleSteps',
        theme: AppTheme.light(),
        scrollBehavior: const AppScrollBehavior(),
        initialRoute: AppRouter.initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
