import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_user.dart';
import '../theme/app_tokens.dart';

/// Thrown when an authentication operation fails.
class AuthException implements Exception {
  /// Creates an [AuthException] with [code] and human-readable [message].
  const AuthException({required this.code, required this.message});

  /// Error code identifying failure reason.
  final String code;

  /// Human-readable, calm error description suitable for UI presentation.
  final String message;

  @override
  String toString() => 'AuthException($code: $message)';
}

/// Abstract contract for authentication services.
abstract class AuthService {
  /// Signs in a caregiver using [email] and [password].
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Creates a new caregiver account with [email] and [password].
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Refreshes the ID token using [refreshToken].
  Future<AuthUser> refreshToken(String refreshToken);

  /// Signs out the current caregiver.
  Future<void> signOut();
}

/// Implementation of [AuthService] using the Firebase Authentication REST API.
///
/// Targets the local Firebase Auth emulator when [useEmulator] is `true`, or
/// live HTTPS Firebase Identity Toolkit endpoints when [useEmulator] is `false`.
class FirebaseAuthRestService implements AuthService {
  /// Creates a [FirebaseAuthRestService].
  FirebaseAuthRestService({
    String? emulatorHost,
    this.emulatorPort = 9099,
    this.apiKey = AppConfig.firebaseApiKey,
    this.useEmulator = AppConfig.useFirebaseEmulator,
    this.requestTimeout = AppMotion.apiRequestTimeout,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client(),
       emulatorHost = emulatorHost ?? defaultEmulatorHost;

  /// HTTP client used for auth requests.
  final http.Client httpClient;

  /// Firebase API key for the active project or emulator.
  final String apiKey;

  /// Whether requests target the local Firebase Auth emulator.
  final bool useEmulator;

  /// Firebase Auth emulator port (defaults to `9099`).
  final int emulatorPort;

  /// Host address for the emulator (defaults to [AppConfig.emulatorHost]).
  final String emulatorHost;

  /// Timeout applied to authentication HTTP requests.
  final Duration requestTimeout;

  /// Returns the default emulator host based on [AppConfig] or platform.
  static String get defaultEmulatorHost => AppConfig.emulatorHost;

  // Base URL for Identity Toolkit endpoints.
  String get _identityBaseUrl => useEmulator
      ? 'http://$emulatorHost:$emulatorPort/identitytoolkit.googleapis.com/v1'
      : 'https://identitytoolkit.googleapis.com/v1';

  // Base URL for secure token endpoints.
  String get _secureTokenBaseUrl => useEmulator
      ? 'http://$emulatorHost:$emulatorPort/securetoken.googleapis.com/v1'
      : 'https://securetoken.googleapis.com/v1';

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(
      '$_identityBaseUrl/accounts:signInWithPassword?key=$apiKey',
    );
    final response = await _postJson(uri, {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    return _handleAuthResponse(response, fallbackEmail: email.trim());
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_identityBaseUrl/accounts:signUp?key=$apiKey');
    final response = await _postJson(uri, {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    return _handleAuthResponse(response, fallbackEmail: email.trim());
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    final uri = Uri.parse('$_secureTokenBaseUrl/token?key=$apiKey');
    final response = await httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
        )
        .timeout(requestTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final expiresIn =
          int.tryParse(json['expires_in']?.toString() ?? '3600') ?? 3600;
      return AuthUser(
        id: json['user_id'] as String? ?? '',
        email: '',
        idToken: json['id_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
    }

    _handleErrorResponse(response);
  }

  @override
  Future<void> signOut() async {
    // In-memory REST auth requires no server-side invalidation against emulator.
  }

  Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) async {
    try {
      return await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const AuthException(
        code: 'auth/network-request-failed',
        message: "We couldn't reach the sign-in service. Check your connection and try again.",
      );
    } on SocketException {
      throw const AuthException(
        code: 'auth/network-request-failed',
        message: "We couldn't reach the sign-in service. Check your connection and try again.",
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        code: 'auth/unknown',
        message: 'Something went wrong while connecting. Please try again.',
      );
    }
  }

  AuthUser _handleAuthResponse(
    http.Response response, {
    required String fallbackEmail,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final user = AuthUser.fromRestJson(json);
      if (user.email.isEmpty) {
        return AuthUser(
          id: user.id,
          email: fallbackEmail,
          idToken: user.idToken,
          refreshToken: user.refreshToken,
          expiresAt: user.expiresAt,
        );
      }
      return user;
    }

    _handleErrorResponse(response);
  }

  Never _handleErrorResponse(http.Response response) {
    String rawCode = 'UNKNOWN';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        rawCode = error['message'] as String? ?? 'UNKNOWN';
      } else if (error is String) {
        rawCode = error;
      }
    } catch (_) {}

    final normalizedCode = _normalizeErrorCode(rawCode);
    final userMessage = _mapErrorMessage(normalizedCode);
    throw AuthException(code: normalizedCode, message: userMessage);
  }

  String _normalizeErrorCode(String rawCode) {
    final stripped = rawCode.split(':').first.trim();
    switch (stripped) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'INVALID_CREDENTIAL':
        return 'auth/invalid-credential';
      case 'EMAIL_EXISTS':
        return 'auth/email-already-in-use';
      case 'USER_DISABLED':
        return 'auth/user-disabled';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'auth/too-many-requests';
      case 'INVALID_EMAIL':
        return 'auth/invalid-email';
      case 'TOKEN_EXPIRED':
      case 'USER_NOT_FOUND':
        return 'auth/user-token-expired';
      default:
        return 'auth/$stripped'.toLowerCase();
    }
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'auth/invalid-credential':
        return "That email and password don't match an account. Please check them and try again.";
      case 'auth/email-already-in-use':
        return 'An account already exists with this email address.';
      case 'auth/invalid-email':
        return 'Please enter a valid email address.';
      case 'auth/too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'auth/network-request-failed':
        return "We couldn't reach the sign-in service. Check your connection and try again.";
      case 'auth/user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'auth/user-token-expired':
        return 'Your session has ended. Please sign in again.';
      default:
        return 'Something went wrong while signing in. Please try again.';
    }
  }
}
