import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { student, staff }

/// Shown when a student ID is already linked to a different name.
class StudentIdentityException implements Exception {
  const StudentIdentityException(this.message);

  final String message;
}

class AppSession {
  const AppSession({
    required this.uid,
    required this.role,
    this.studentId,
    this.name,
  });

  final String uid;
  final UserRole role;
  final String? studentId;
  final String? name;

  bool get isStaff => role == UserRole.staff;
}

class AuthService {
  /// The signed-in person, available to any screen.
  static AppSession? current;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppSession _remember(AppSession session) {
    current = session;
    return session;
  }

  /// Restores a previous login when the app is reopened.
  /// Returns null when nobody is signed in.
  Future<AppSession?> restoreSession() async {
    // On the web, Firebase restores the saved user asynchronously,
    // so wait for the first auth state instead of reading currentUser.
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;

    try {
      if (user.isAnonymous) {
        final doc = await _db.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data == null) {
          await _auth.signOut();
          return null;
        }
        return _remember(
          AppSession(
            uid: user.uid,
            role: UserRole.student,
            studentId: data['studentId'] as String?,
            name: data['name'] as String?,
          ),
        );
      }

      if (await _isStaff(user.uid)) {
        return _remember(
          AppSession(uid: user.uid, role: UserRole.staff, name: user.email),
        );
      }

      await _auth.signOut();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AppSession> signInStudent({
    required String studentId,
    required String name,
  }) async {
    if (_auth.currentUser != null) await _auth.signOut();

    final credential = await _auth.signInAnonymously();
    final user = credential.user!;
    final cleanId = studentId.trim();
    final cleanName = name.trim();
    final identityRef = _db.collection('student_ids').doc(cleanId);
    final userRef = _db.collection('users').doc(user.uid);

    try {
      await _db.runTransaction((transaction) async {
        final identity = await transaction.get(identityRef);

        if (identity.exists) {
          final savedName = (identity.data()?['name'] as String? ?? '').trim();
          if (savedName != cleanName) {
            throw const StudentIdentityException(
              'This Student ID is already registered with a different name.',
            );
          }
        } else {
          transaction.set(identityRef, {
            'studentId': cleanId,
            'name': cleanName,
            'ownerUid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.set(userRef, {
          'role': 'student',
          'studentId': cleanId,
          'name': cleanName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on StudentIdentityException {
      await _auth.signOut();
      rethrow;
    }

    return _remember(
      AppSession(
        uid: user.uid,
        role: UserRole.student,
        studentId: cleanId,
        name: cleanName,
      ),
    );
  }

  Future<AppSession> signInStaff({
    required String email,
    required String password,
  }) async {
    if (_auth.currentUser != null) await _auth.signOut();

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    if (!await _isStaff(user.uid)) {
      await _auth.signOut();
      throw StateError('not-staff');
    }

    return _remember(
      AppSession(uid: user.uid, role: UserRole.staff, name: user.email),
    );
  }

  Future<void> signOut() async {
    current = null;
    await _auth.signOut();
  }

  Future<bool> _isStaff(String uid) async {
    final doc = await _db.collection('staff').doc(uid).get();
    return doc.exists;
  }
}
