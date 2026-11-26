// The profile of a logged-in person, saved in Firestore at users/{uid}.

import 'firestore_date.dart';

/// The three kinds of users. Admin can't be picked when registering; it is
/// set by hand in the Firebase console.
class UserRole {
  UserRole._();

  static const String farmer = 'farmer';
  static const String buyer = 'buyer';
  static const String admin = 'admin';
}

/// One user's profile.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.town,
    required this.about,
    required this.createdAt,
  });

  final String id; // same as the Firebase Auth uid
  final String name;
  final String email;
  final String role; // one of UserRole
  final String town;
  final String about; // short "about me / my farm", can be empty
  final DateTime createdAt;

  bool get isFarmer => role == UserRole.farmer;
  bool get isBuyer => role == UserRole.buyer;
  bool get isAdmin => role == UserRole.admin;

  /// Builds a user from a Firestore document. Missing fields get safe defaults.
  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      name: data['name'] as String? ?? 'No name',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? UserRole.buyer,
      town: data['town'] as String? ?? '',
      about: data['about'] as String? ?? '',
      createdAt: readDate(data['createdAt']),
    );
  }

  /// The fields we save to Firestore. createdAt is added by the service.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'town': town,
      'about': about,
    };
  }
}
