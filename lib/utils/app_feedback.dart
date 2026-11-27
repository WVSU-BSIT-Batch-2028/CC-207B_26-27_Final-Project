import 'dart:async';

import 'package:flutter/material.dart';

import '../foodwise_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackType { success, info, warning, error }

class FeedbackData {
  final String title;
  final String message;
  final FeedbackType type;
  final String? actionLabel;

  const FeedbackData({
    required this.title,
    required this.message,
    required this.type,
    this.actionLabel,
  });

  Color get color => switch (type) {
    FeedbackType.success => FoodWiseColors.success,
    FeedbackType.info => FoodWiseColors.info,
    FeedbackType.warning => FoodWiseColors.warning,
    FeedbackType.error => FoodWiseColors.error,
  };
  IconData get icon => switch (type) {
    FeedbackType.success => Icons.check_circle_outline_rounded,
    FeedbackType.info => Icons.info_outline_rounded,
    FeedbackType.warning => Icons.warning_amber_rounded,
    FeedbackType.error => Icons.error_outline_rounded,
  };
}

class AppFeedback {
  const AppFeedback._();

  static FeedbackData success(
    String title,
    String message, {
    String? actionLabel,
  }) => FeedbackData(
    title: title,
    message: message,
    type: FeedbackType.success,
    actionLabel: actionLabel,
  );
  static FeedbackData info(String title, String message) =>
      FeedbackData(title: title, message: message, type: FeedbackType.info);
  static FeedbackData warning(String title, String message) =>
      FeedbackData(title: title, message: message, type: FeedbackType.warning);
  static FeedbackData failure(String title, String message) =>
      FeedbackData(title: title, message: message, type: FeedbackType.error);

  /// Translate known backend errors; never return raw exception text to the UI.
  static FeedbackData fromError(
    Object error, {
    String title = 'Something went wrong',
    String fallback = 'Please try again in a moment.',
    String? invalidCredentialsMessage,
  }) {
    final raw = error.toString().toLowerCase();
    final code = error is AuthException ? error.code : null;
    if (code == 'email_not_confirmed' || raw.contains('email not confirmed')) {
      return const FeedbackData(
        title: 'Verify your email address',
        message: 'Check your inbox or spam folder for the confirmation link before signing in.',
        type: FeedbackType.warning,
        actionLabel: 'Resend verification email',
      );
    }
    if (code == 'invalid_credentials' ||
        raw.contains('invalid login credentials')) {
      return failure(
        title,
        invalidCredentialsMessage ?? 'Your email or password is incorrect. Check your details and try again.',
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        raw.contains('already registered') ||
        raw.contains('already been registered')) {
      return warning(
        'Email already registered',
        'Try signing in, resetting your password, or using a different email address.',
      );
    }
    if (code == 'email_address_invalid' || raw.contains('invalid email')) {
      return warning(
        'Check your email address',
        'Enter a valid email address and try again.',
      );
    }
    if (code == 'weak_password') {
      return warning(
        'Choose a stronger password',
        'Your password does not meet the security requirements. Try a stronger password.',
      );
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        raw.contains('rate limit') ||
        raw.contains('statuscode: 429') ||
        raw.contains('status code: 429')) {
      return warning(
        'Too many requests',
        'Please wait a little while before trying again.',
      );
    }
    if (code == 'otp_expired') {
      return warning(
        'Verification expired',
        'Request a new verification link or code and try again.',
      );
    }
    if (code == 'session_not_found' ||
        code == 'session_expired' ||
        code == 'refresh_token_not_found' ||
        raw.contains('session has expired') ||
        raw.contains('no signed-in')) {
      return warning('Session expired', 'Please sign in again to continue.');
    }
    if (error is TimeoutException ||
        raw.contains('timed out') ||
        raw.contains('timeoutexception')) {
      return warning(
        'Request timed out',
        'Check your connection and try again.',
      );
    }
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('failed to fetch') ||
        raw.contains('xmlhttprequest error') ||
        raw.contains('networkerror')) {
      return failure(
        'Connection unavailable',
        'Check your internet connection and try again.',
      );
    }
    if (error is PostgrestException && error.code == '23505') {
      return info('Already saved', 'This information has already been saved.');
    }
    if ((error is PostgrestException && error.code == '42501') ||
        raw.contains('row-level security') ||
        raw.contains('permission denied')) {
      return failure(
        'Access restricted',
        'Your account cannot complete this action. Please contact support if the problem continues.',
      );
    }
    if (raw.contains('bucket not found') || raw.contains('no such bucket')) {
      return failure(
        'Photo storage unavailable',
        'Profile photo storage is not available yet. Please contact support.',
      );
    }
    if (raw.contains('payload too large') ||
        raw.contains('file size limit') ||
        raw.contains('smaller than 5 mb')) {
      return warning('Image too large', 'Choose a photo smaller than 5 MB.');
    }
    if (error is FormatException && raw.contains('jpg, png, or webp')) {
      return warning('Unsupported image', 'Choose a JPG, PNG, or WebP image.');
    }
    if (error is FormatException && raw.contains('selected image is empty')) {
      return warning('Empty image', 'Choose another photo and try again.');
    }
    if (error is StorageException) {
      return failure('Unable to access photo', fallback);
    }
    return failure(title, fallback);
  }

  static void show(
    BuildContext context,
    FeedbackData feedback, {
    VoidCallback? onAction,
  }) {
    showWithMessenger(
      ScaffoldMessenger.of(context),
      feedback,
      onAction: onAction,
    );
  }

  /// Useful when a saved item disappears and its original context is unmounted.
  static void showWithMessenger(
    ScaffoldMessengerState messenger,
    FeedbackData feedback, {
    VoidCallback? onAction,
  }) {
    if (!messenger.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: feedback.color,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FoodWiseRadius.feedback),
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(feedback.icon, color: FoodWiseColors.surface),
            const SizedBox(width: FoodWiseSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.title,
                    style: const TextStyle(
                      color: FoodWiseColors.surface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feedback.message,
                    style: const TextStyle(color: FoodWiseColors.surface),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: feedback.actionLabel != null && onAction != null
            ? SnackBarAction(
                label: feedback.actionLabel!,
                textColor: FoodWiseColors.surface,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
