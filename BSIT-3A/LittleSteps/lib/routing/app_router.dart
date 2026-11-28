import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../screens/account/account_info_screen.dart';
import '../screens/account/settings_screen.dart';
import '../screens/ai/ai_suggestions_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/signed_out_screen.dart';
import '../screens/children/add_child_screen.dart';
import '../screens/children/child_profile_screen.dart';
import '../screens/explore/activity_detail_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../widgets/auth_scope.dart';

/// Canonical named route paths used throughout the application.
abstract final class AppRoutes {
  /// Root route resolving to [ShellScreen] or [SignInScreen].
  static const String home = '/';

  /// Initial splash screen route.
  static const String splash = '/splash';

  /// Caregiver sign-in screen route.
  static const String signIn = '/sign-in';

  /// Caregiver registration screen route.
  static const String register = '/register';

  /// Session expiration / signed-out confirmation route.
  static const String signedOut = '/signed-out';

  /// Alias route for account settings.
  static const String account = '/account';

  /// Caregiver settings screen route.
  static const String accountSettings = '/account/settings';

  /// Privacy notice information screen route.
  static const String accountPrivacy = '/account/privacy';

  /// About LittleSteps information screen route.
  static const String accountAbout = '/account/about';

  /// Help and support information screen route.
  static const String accountHelp = '/account/help';

  /// Child profile switcher and management screen route.
  static const String children = '/children';

  /// Add child profile screen route.
  static const String childrenAdd = '/children/add';

  /// AI Idea Helper play-suggestion route.
  ///
  /// Accepts an optional [String] argument specifying an initial play setting
  /// (`indoor`, `outdoor`, or `either`).
  static const String aiSuggest = '/ai-suggest';

  /// Activity detail screen route accepting an [Activity] argument.
  static const String exploreActivity = '/explore/activity';
}

/// Application route generator and path constants.
abstract final class AppRouter {
  /// Initial route loaded on application launch.
  static const String initialRoute = AppRoutes.home;

  /// Generates application routes based on [RouteSettings].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            if (auth == null || !auth.isAuthenticated) {
              return const SignInScreen();
            }
            return const ShellScreen();
          },
        );
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.signIn:
        final notice = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => SignInScreen(notice: notice));
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.signedOut:
        final message =
            settings.arguments as String? ?? 'Please sign in again to continue';
        return MaterialPageRoute(
          builder: (_) => SignedOutScreen(message: message),
        );
      case AppRoutes.account:
      case AppRoutes.accountSettings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.accountPrivacy:
        return MaterialPageRoute(
          builder: (_) =>
              const AccountInfoScreen(page: AccountInfoPage.privacy),
        );
      case AppRoutes.accountAbout:
        return MaterialPageRoute(
          builder: (_) => const AccountInfoScreen(page: AccountInfoPage.about),
        );
      case AppRoutes.accountHelp:
        return MaterialPageRoute(
          builder: (_) => const AccountInfoScreen(page: AccountInfoPage.help),
        );
      case AppRoutes.children:
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            if (auth == null || !auth.isAuthenticated) {
              return const SignInScreen(
                notice: 'Please sign in to view and manage child profiles.',
              );
            }
            return const ChildProfileScreen();
          },
        );
      case AppRoutes.childrenAdd:
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            if (auth == null || !auth.isAuthenticated) {
              return const SignInScreen(
                notice: 'Please sign in before adding a child profile.',
              );
            }
            return const AddChildScreen();
          },
        );
      case AppRoutes.aiSuggest:
        final initialSetting = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            return AiSuggestionsScreen(
              initialChild: auth?.activeChild,
              initialSetting: initialSetting,
            );
          },
        );
      case AppRoutes.exploreActivity:
        final args = settings.arguments;
        if (args is ActivityDetailArgs) {
          return MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(
              activity: args.activity,
              startInAdaptMode: args.startInAdaptMode,
            ),
          );
        }
        if (args is Activity) {
          return MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: args),
          );
        }
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Activity not found'))),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
