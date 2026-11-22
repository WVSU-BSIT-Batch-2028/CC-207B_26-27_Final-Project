import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_providers.dart';
import '../screens/admin/admin_shell_screen.dart';
import '../screens/admin/audit/audit_detail_screen.dart';
import '../screens/admin/sign_in/admin_sign_in_screen.dart';
import '../screens/shared/change_password_screen.dart';
import 'password_redirect.dart';

// Pages an administrator can open
final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      return redirectForAdminSession(
        ref.read(sessionProvider),
        state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AdminSignInScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/pharmacies',
        builder: (context, state) =>
            const AdminShellScreen(section: 'pharmacies'),
      ),
      GoRoute(
        path: '/catalogue',
        builder: (context, state) =>
            const AdminShellScreen(section: 'catalogue'),
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) =>
            const AdminShellScreen(section: 'requests'),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const AdminShellScreen(section: 'audit'),
      ),
      GoRoute(
        path: '/audit/:id',
        builder: (context, state) =>
            AuditDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listings',
        builder: (context, state) =>
            const AdminShellScreen(section: 'listings'),
      ),
    ],
  );
});
