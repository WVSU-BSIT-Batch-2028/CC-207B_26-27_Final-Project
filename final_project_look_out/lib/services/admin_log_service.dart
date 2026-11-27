import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> adminLogData({
  required String title,
  required String description,
  required String type,
}) {
  final user = FirebaseAuth.instance.currentUser;

  return {
    'title': title,
    'description': description,
    'actor': user?.email ?? user?.uid ?? 'Admin',
    'actorUid': user?.uid,
    'type': type,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
