import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<AuthResponse> registerStudent({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  static Future<AuthResponse> loginStudent({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    return _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  static bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }
}
