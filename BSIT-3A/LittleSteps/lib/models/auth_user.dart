import 'package:flutter/foundation.dart';

/// An authenticated caregiver user.
@immutable
class AuthUser {
  /// Creates an [AuthUser].
  const AuthUser({
    required this.id,
    required this.email,
    required this.idToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// Creates an [AuthUser] from Firebase REST authentication JSON.
  factory AuthUser.fromRestJson(Map<String, dynamic> json) {
    final expiresInSeconds =
        int.tryParse(json['expiresIn']?.toString() ?? '3600') ?? 3600;
    return AuthUser(
      id: json['localId'] as String? ?? json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      idToken: json['idToken'] as String? ?? json['id_token'] as String? ?? '',
      refreshToken:
          json['refreshToken'] as String? ?? json['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }

  /// Unique Firebase local user ID.
  final String id;

  /// Caregiver email address.
  final String email;

  /// Verified Firebase ID token sent on protected requests.
  final String idToken;

  /// Refresh token used to obtain a new ID token upon expiry.
  final String? refreshToken;

  /// Expiry timestamp for [idToken].
  final DateTime? expiresAt;

  /// Whether the current [idToken] has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Returns a copy of this [AuthUser] with updated token fields.
  AuthUser copyWith({
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return AuthUser(
      id: id,
      email: email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
