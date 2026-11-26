// Logging in, registering and logging out with Firebase Auth. The user's
// profile (name, role, town) is saved in Firestore at users/{uid}.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../utils/app_exception.dart';

/// Everything about the logged-in user.
class AuthService {
  /// The logged-in user's profile. Set after login or register, cleared on
  /// log out. Screens read it with `AuthService.currentUser`.
  static AppUser? currentUser;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  /// Logs in and loads the profile into [currentUser].
  Future<AppUser> logIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await loadProfile(result.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e.code));
    }
  }

  /// Creates the account, then saves the profile in Firestore.
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String town,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = AppUser(
        id: result.user!.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        town: town,
        about: '',
        createdAt: DateTime.now(),
      );
      await runSafely('save profile', () {
        return _users.doc(user.id).set({
          ...user.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          // When the user agreed to the privacy notice (RA 10173).
          'consentAt': FieldValue.serverTimestamp(),
        });
      });
      currentUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e.code));
    }
  }

  /// Loads users/{uid} into [currentUser]. Used after login and when the app
  /// starts while someone is still logged in.
  Future<AppUser> loadProfile(String uid) async {
    final doc = await runSafely('load profile', () => _users.doc(uid).get());
    if (!doc.exists) {
      throw const AppException(
        'Your profile was not found. Please register again.',
      );
    }
    currentUser = AppUser.fromMap(doc.id, doc.data()!);
    return currentUser!;
  }

  /// Loads another user's profile, e.g. a farmer's page.
  Future<AppUser> loadOtherUser(String uid) async {
    final doc = await runSafely('load user', () => _users.doc(uid).get());
    if (!doc.exists) throw const AppException('This user was not found.');
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  /// Saves the logged-in user's name, town and "about" text, and updates
  /// [currentUser] so every screen shows the new values. Email and role
  /// can't be changed here (the rules don't allow changing the role).
  Future<AppUser> updateProfile({
    required String name,
    required String town,
    required String about,
  }) async {
    final me = currentUser!;
    await runSafely('update profile', () {
      return _users.doc(me.id).update({
        'name': name.trim(),
        'town': town,
        'about': about.trim(),
      });
    });
    currentUser = AppUser(
      id: me.id,
      name: name.trim(),
      email: me.email,
      role: me.role,
      town: town,
      about: about.trim(),
      createdAt: me.createdAt,
    );
    return currentUser!;
  }

  /// The Firebase Auth user id if someone is still logged in from last time.
  String? get savedLoginId => _auth.currentUser?.uid;

  Future<void> logOut() async {
    await _auth.signOut();
    currentUser = null;
  }

  /// Turns Firebase Auth error codes into messages that say how to fix them.
  String _authMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong email or password. Check them and try again.';
      case 'email-already-in-use':
        return 'This email already has an account. Log in instead.';
      case 'invalid-email':
        return 'Enter a valid email, like name@example.com.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many tries. Wait a few minutes, then try again.';
      case 'network-request-failed':
        return 'Could not connect. Check your internet and try again.';
      default:
        return 'Could not log in right now. Please try again.';
    }
  }
}
