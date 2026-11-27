//created this file - Joshua


//firebase auth and firestore db
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //signup
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    //create user in Firebase Auth
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    //create user in Firestore
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email.trim().toLowerCase(),
      'fullName': fullName.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  //login AUth
  Future<dynamic> login({
    required String email,
    required String password,
    required String loginTab,
  }) async {
    UserCredential cred = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final docRef = _db.collection('users').doc(cred.user!.uid);

    final DocumentSnapshot userDoc = await docRef.get();

    if (!userDoc.exists) return null;

    await docRef.update({
      'loginTab': loginTab,
      'updatedAt' : FieldValue.serverTimestamp()
      });

    return userDoc.data();
  }

  Future<void> signOut() => _auth.signOut();
}
