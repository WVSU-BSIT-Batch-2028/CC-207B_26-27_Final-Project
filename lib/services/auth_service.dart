import 'dart:async' as async;

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_role.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

typedef UserProfileMap = Map<String, dynamic>;

class AuthService {
  bool get isConfigured => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  fs.FirebaseFirestore get _firestore => fs.FirebaseFirestore.instance;

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedProfile;

  async.Stream<User?> get authStateChanges =>
      isConfigured ? _auth.authStateChanges() : async.Stream.value(null);

  User? get currentUser => isConfigured ? _auth.currentUser : null;

  async.Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    bool privacyAccepted = true,
  }) async {
    if (!isConfigured) {
      throw const AuthException(
        'Firebase is not configured yet. Add firebase_config.json to run live authentication.',
      );
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(fullName.trim());

      final data = <String, dynamic>{
        'uid': uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'role': role.name, 
        'privacyAccepted': privacyAccepted,
        'createdAt': fs.FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(data);
      _cachedUid = uid;
      _cachedProfile = data;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to save user profile.');
    }
  }

  async.Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      throw const AuthException(
        'Firebase is not configured yet. Add firebase_config.json to run live authentication.',
      );
    }
    try {
      _clearCache();
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  async.Future<UserProfileMap?> getUserProfile(String uid) async {
    if (!isConfigured) return null;
    if (_cachedUid == uid && _cachedProfile != null) {
      return _cachedProfile;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      _cachedUid = uid;
      _cachedProfile = doc.data();
      return _cachedProfile;
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Unable to load user profile.');
    }
  }

  async.Future<UserRole> getUserRole(String uid) async {
    if (!isConfigured) return UserRole.patient;
    try {
      final data = await getUserProfile(uid);
      if (data == null) {
        throw const AuthException(
          'User profile not found in Firestore. Please contact support or register again.',
        );
      }
      final roleStr = data['role'] as String?;
      if (roleStr == 'doctor') return UserRole.doctor;
      if (roleStr == 'patient') return UserRole.patient;
      throw const AuthException('Invalid user role configured on account.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to verify account role: $e');
    }
  }

  async.Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isConfigured) {
      throw const AuthException('Firebase is not configured.');
    }
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('No signed-in user found.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  async.Future<void> sendPasswordReset(String email) async {
    if (!isConfigured) {
      throw const AuthException(
        'Firebase is not configured yet. Add firebase_config.json to run live authentication.',
      );
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  async.Future<void> signOut() async {
    _clearCache();
    if (!isConfigured) return;
    await _auth.signOut();
  }

  static void _clearCache() {
    _cachedUid = null;
    _cachedProfile = null;
  }

  static void forgetCachedProfile() => _clearCache();

  AuthException _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return AuthException('Invalid email or password.', code: e.code);
      case 'wrong-password':
        return AuthException('Incorrect current password. Please try again.', code: e.code);
      case 'email-already-in-use':
        return AuthException('An account already exists with this email.', code: e.code);
      case 'weak-password':
        return AuthException('Password does not meet security requirements.', code: e.code);
      case 'invalid-email':
        return AuthException('Please enter a valid email address.', code: e.code);
      case 'requires-recent-login':
        return AuthException('Please sign out and sign in again before changing your password.', code: e.code);
      case 'too-many-requests':
        return AuthException('Too many attempts. Please wait a moment and try again.', code: e.code);
      default:
        return AuthException(
          e.message ?? 'Authentication failed. Please try again.',
          code: e.code,
        );
    }
  }
}
