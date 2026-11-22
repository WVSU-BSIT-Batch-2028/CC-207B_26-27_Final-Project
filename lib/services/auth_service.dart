import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_role.dart';

/// Handles Firebase Email/Password authentication and Firestore user role storage.
class AuthService {
  bool get isConfigured => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Emits the current Firebase User whenever sign-in or sign-out occurs.
  Stream<User?> get authStateChanges =>
      isConfigured ? _auth.authStateChanges() : Stream.value(null);

  User? get currentUser => isConfigured ? _auth.currentUser : null;

  /// Creates a new Firebase Auth account and saves their profile + role in Firestore `users/{uid}`.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (!isConfigured) {
      throw 'Firebase is not configured yet. Ask your team leader for firebase_config.json.';
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(fullName.trim());

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'role': role.name, // Stores 'patient' or 'doctor'
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Signs an existing user in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      throw 'Firebase is not configured yet. Ask your team leader for firebase_config.json.';
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Reads the user's assigned role ('patient' or 'doctor') from Firestore `users/{uid}`.
  Future<UserRole> getUserRole(String uid) async {
    if (!isConfigured) return UserRole.patient;
    final doc = await _firestore.collection('users').doc(uid).get();
    final roleStr = doc.data()?['role'] as String? ?? 'patient';
    return roleStr == 'doctor' ? UserRole.doctor : UserRole.patient;
  }

  /// Sends a password reset link to the given email address.
  Future<void> sendPasswordReset(String email) async {
    if (!isConfigured) {
      throw 'Firebase is not configured yet. Ask your team leader for firebase_config.json.';
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    if (!isConfigured) return;
    await _auth.signOut();
  }

  /// Converts Firebase error codes into clear user-facing messages.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}