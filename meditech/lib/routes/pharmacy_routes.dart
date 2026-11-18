import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_providers.dart';
import '../screens/pharmacy/activity_log/activity_log_screen.dart';
import '../screens/pharmacy/registration/registration_screen.dart';
import '../screens/pharmacy/sign_in/pharmacy_sign_in_screen.dart';
import '../screens/shared/change_password_screen.dart';
import '../screens/shared/notification_list_screen.dart';
import 'password_redirect.dart';

// Pages a pharmacy user can open
final pharmacyRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      return redirectForPasswordChange(
        ref.read(sessionProvider),
        state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PharmacySignInScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/activity-log',
        builder: (context, state) => const ActivityLogScreen(),
      ),
    ],
  );
});