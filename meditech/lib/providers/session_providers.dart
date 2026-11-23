import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/signed_in_account.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthService();
});

class SessionNotifier extends Notifier<SignedInAccount?> {
  @override
  SignedInAccount? build() => null;

  Future<void> signIn({
    required String identifier,
    required String password,
    required String app,
  }) async {
    final account = await ref.read(authServiceProvider).signIn(
          identifier: identifier,
          password: password,
          app: app,
        );
    state = account;
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = null;
  }
  
  void passwordWasChanged() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(mustChangePassword: false);
  }

  // Keep the session after sign-up, without asking them to sign in again
  void setSignedIn(SignedInAccount account) {
    state = account;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SignedInAccount?>(SessionNotifier.new);

/// Reads JWT claims from a persisted Supabase session (after browser refresh).
SignedInAccount? signedInAccountFromStoredSession() {
  try {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    return SignedInAccount.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return null;
  }
}

/// Fills [sessionProvider] when Supabase already has a session but Riverpod does not.
void restoreSessionIfNeeded({
  required SignedInAccount? currentSession,
  required void Function(SignedInAccount account) setSignedIn,
}) {
  if (currentSession != null) return;
  final account = signedInAccountFromStoredSession();
  if (account == null) return;
  setSignedIn(account);
}
