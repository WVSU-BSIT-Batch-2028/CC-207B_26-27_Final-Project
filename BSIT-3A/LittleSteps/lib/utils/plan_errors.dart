import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/api_client.dart';

/// Maps a plan-scheduling [error] into calm caregiver-facing snackbar copy.
///
/// The [subject] phrase describes what failed to schedule (for example,
/// `'the activity'` or `'activities'`).
String formatPlanErrorMessage(
  Object error, {
  String subject = 'this activity',
}) {
  return switch (error) {
    ApiException(code: 'SERVICE_UNAVAILABLE') =>
      'The plan service is temporarily unavailable. Try again in a moment.',
    NoConnectionApiException() ||
    TimeoutApiException() ||
    SocketException() ||
    http.ClientException() =>
      "Could not add $subject to today's plan. Check your connection and try again.",
    NotFoundApiException() => 'The child or activity was not found. Check that the child profile is saved to your account.',
    AuthApiException() => 'Sign in again before adding an activity.',
    _ => "Could not add $subject to today's plan. Please try again.",
  };
}
