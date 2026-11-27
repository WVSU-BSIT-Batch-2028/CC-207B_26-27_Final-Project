import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';

/// What kind of data changed, so the shell knows which tabs to reload.
enum LiveTopic { appointments, prescriptions, records }

/// Tells the patient and doctor shells when the signed-in user's data
/// changes in Firestore, so every tab can update without a manual refresh.
/// Same idea as doctor Home's `watchChanges()`: Firestore `snapshots()`
/// listeners, skipping each first snapshot (the data already on screen).
class LiveUpdatesService {
  LiveUpdatesService._();

  static final LiveUpdatesService instance = LiveUpdatesService._();

  /// Emits a [LiveTopic] each time matching data changes for [role].
  /// Emits nothing without Firebase or a signed-in user.
  Stream<LiveTopic> watch(UserRole role) {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream<LiveTopic>.empty();

    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> mine(String collection, String field) =>
        db.collection(collection).where(field, isEqualTo: user.uid);

    // Each query and the topic it belongs to.
    final watched = role == UserRole.patient
        ? <(Query<Map<String, dynamic>>, LiveTopic)>[
            (mine('appointments', 'patientId'), LiveTopic.appointments),
            (mine('prescriptions', 'patientId'), LiveTopic.prescriptions),
            (mine('refillRequests', 'patientId'), LiveTopic.prescriptions),
            (mine('labResults', 'patientId'), LiveTopic.records),
            (mine('consultations', 'patientId'), LiveTopic.records),
          ]
        : <(Query<Map<String, dynamic>>, LiveTopic)>[
            (mine('appointments', 'doctorId'), LiveTopic.appointments),
          ];

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<LiveTopic> controller;
    controller = StreamController<LiveTopic>(
      onListen: () {
        for (final (query, topic) in watched) {
          var first = true;
          subs.add(query.snapshots().listen(
            (_) {
              if (first) {
                first = false;
                return;
              }
              controller.add(topic);
            },
            onError: (Object e) => debugPrint('Live update stopped (${topic.name}): $e'),
          ));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }
}
