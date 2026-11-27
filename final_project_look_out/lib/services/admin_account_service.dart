import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/admin_log_service.dart';

class AdminAccountService {
  static Future<void> createAccount({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('createUserAccount')
        .call({
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': role,
        });
  }

  static Future<void> deleteAccount({
    required String uid,
    required String fullName,
    required String email,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.delete(db.collection('users').doc(uid));
    batch.set(
      db.collection('logs').doc(),
      adminLogData(
        title: 'Account profile deleted',
        description: '$fullName ($email)',
        type: 'Account',
      ),
    );
    await batch.commit();
  }
}
