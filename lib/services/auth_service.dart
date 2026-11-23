import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  // STUDENT REGISTRATION
  static Future<AuthResponse> registerStudent({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );

    return response;
  }

  // STUDENT LOGIN
  static Future<AuthResponse> loginStudent({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    return response;
  }

  // GET CURRENT STUDENT PROFILE
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return profile;
  }

  // LOGOUT
  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  // CHECK CURRENT SESSION
  static bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }
}
