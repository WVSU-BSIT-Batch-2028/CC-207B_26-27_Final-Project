import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_session_state.dart';

/// Provides [AuthSessionState] and [ApiClient] to descendant widgets.
class AuthScope extends InheritedNotifier<AuthSessionState> {
  /// Creates an [AuthScope].
  const AuthScope({
    super.key,
    required AuthSessionState sessionState,
    required this.apiClient,
    required super.child,
  }) : super(notifier: sessionState);

  /// The active [ApiClient] configured for the current session.
  final ApiClient apiClient;

  /// Returns the nearest [AuthSessionState] from [context].
  static AuthSessionState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context');
    return scope!.notifier!;
  }

  /// Returns the nearest [AuthSessionState] from [context], or `null` if not found.
  static AuthSessionState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }

  /// Returns the nearest [ApiClient] from [context].
  static ApiClient apiClientOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context');
    return scope!.apiClient;
  }

  /// Returns the nearest [ApiClient] from [context], or a default [ApiClient].
  static ApiClient apiClientOrDefault(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    return scope?.apiClient ?? ApiClient();
  }
}
