import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/customer_nav_provider.dart';
import '../screens/customer/assistant/assistant_screen.dart';
import '../screens/customer/cart/cart_screen.dart';
import '../screens/customer/customer_frame.dart';
import '../screens/customer/forgot_password/check_email_screen.dart';
import '../screens/customer/forgot_password/forgot_password_screen.dart';
import '../screens/customer/forgot_password/reset_password_screen.dart';
import '../screens/customer/landing/landing_screen.dart';
import '../screens/customer/login/login_screen.dart';
import '../screens/customer/medicine/medicine_details_screen.dart';
import '../screens/customer/pharmacy/pharmacy_details_screen.dart';
import '../screens/customer/pharmacy/pharmacy_directions_screen.dart';
import '../screens/customer/pharmacy/pharmacy_map_screen.dart';
import '../screens/customer/profile/privacy_notice_screen.dart';
import '../screens/customer/profile/profile_screen.dart';
import '../screens/customer/reservations/reservation_details_screen.dart';
import '../screens/customer/reservations/reservation_submitted_screen.dart';
import '../screens/customer/sign_up/account_created_screen.dart';
import '../screens/customer/sign_up/sign_up_screen.dart';
import '../models/medicine.dart';
import '../screens/shared/change_password_screen.dart';
import '../screens/shared/notification_list_screen.dart';
import '../providers/session_providers.dart';
import 'password_redirect.dart';

// Pages a customer can open
final customerRouterProvider = Provider<GoRouter>((ref) {
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
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/home', builder: (context, state) => const CustomerFrame()),
      GoRoute(path: '/sign-in', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/login', redirect: (context, state) => '/sign-in'),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
        routes: [
          GoRoute(
            path: 'check-email',
            builder: (context, state) => CheckEmailScreen(
              identifier: state.extra is String ? state.extra as String : null,
            ),
          ),
          GoRoute(
            path: 'reset',
            builder: (context, state) => ResetPasswordScreen(
              identifier: state.extra is String ? state.extra as String : null,
            ),
          ),
        ],
      ),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/account-created',
        builder: (context, state) => const AccountCreatedScreen(),
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/assistant', builder: (context, state) => const AssistantScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyNoticeScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationListScreen(
          onOpen: (item) {
            final reservationId = item.reservationId;
            if (reservationId == null || reservationId.isEmpty) return;
            context.push('/reservations/$reservationId');
          },
        ),
      ),
      GoRoute(
        path: '/reservations/:id',
        builder: (context, state) => ReservationDetailsScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/reservation-submitted',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! ReservationSubmittedArgs) {
            return const Scaffold(
              body: Center(child: Text('Reservation submitted')),
            );
          }
          return ReservationSubmittedScreen(
            reservationId: extra.reservationId,
            referenceNo: extra.referenceNo,
            pharmacyName: extra.pharmacyName,
            branchName: extra.branchName,
            items: extra.items,
            totalAmount: extra.totalAmount,
            onViewReservation: () {
              ref.read(customerTabProvider.notifier).select(2);
              context.pushReplacement('/reservations/${extra.reservationId}');
            },
            onBackToHome: () {
              ref.read(customerTabProvider.notifier).select(0);
              context.go('/home');
            },
          );
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/medicines',
        builder: (context, state) {
          final medicine = state.extra;
          if (medicine is! MedicineSearchResult) {
            return const Scaffold(
              body: Center(child: Text('Medicine not found.')),
            );
          }
          return MedicineDetailsScreen(medicine: medicine);
        },
      ),
      GoRoute(
        path: '/directions',
        builder: (context, state) => PharmacyDirectionsScreen(
          branchId: state.uri.queryParameters['branch'] ?? '',
          initialTitle: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => PharmacyMapScreen(
          focusBranchId: state.uri.queryParameters['branch'],
        ),
      ),
      GoRoute(
        path: '/pharmacies/:branchId',
        builder: (context, state) => PharmacyDetailsScreen(
          branchId: state.pathParameters['branchId']!,
          initialTitle: state.uri.queryParameters['name'],
        ),
      ),
    ],
  );
});
