import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';

class FirestorePokeService {
  FirestorePokeService._();

  static final FirestorePokeService instance = FirestorePokeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _pokeAudioPlayer = AudioPlayer();
  final Map<String, Set<String>> _knownPokeIdsByPlate = {};
  final Set<String> _initializedPokePlates = {};

  //when poke in Commuter is clicked
  Future<void> sendPoke({
    required String toPlate,
    required String routeId,
    required LatLng location,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send a poke.');
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final fromName =
        userSnapshot.data()?['fullName'] as String? ?? user.email ?? 'Commuter';
    final pokeReference = _firestore.collection('pokes').doc();

    final batch = _firestore.batch();
    batch.set(pokeReference, {
      'pokeId': pokeReference.id,
      'createdAt': FieldValue.serverTimestamp(),
      'fromName': fromName,
      'fromUid': user.uid,
      'lat': location.latitude,
      'lng': location.longitude,
      'message': message,
      'routeId': routeId,
      'toPlate': toPlate,
    });
    batch.set(_firestore.collection('poke_counts').doc(toPlate), {
      'count': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  // on Driver side, add poke count
  Stream<int> streamPokeCount(String activePlate) {
    if (activePlate.isEmpty) {
      return Stream<int>.value(0);
    }

    return _firestore
        .collection('poke_counts')
        .doc(activePlate)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.data()?['count'];
          return count is num ? count.toInt() : 0;
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamIncomingPokes(
    String activePlate,
  ) {
    if (activePlate.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
        <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      );
    }
    return _firestore
        .collection('pokes')
        .where('toPlate', isEqualTo: activePlate)
        .snapshots()
        .map((snapshot) {
          final pokes = snapshot.docs
              .where((poke) => poke.data()['recordType'] != 'ride')
              .toList();
          _playSoundForNewPokes(activePlate, pokes);
          pokes.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            final aMillis = aTime is Timestamp
                ? aTime.millisecondsSinceEpoch
                : 0;
            final bMillis = bTime is Timestamp
                ? bTime.millisecondsSinceEpoch
                : 0;
            return bMillis.compareTo(aMillis);
          });
          return pokes;
        });
  }

  void _playSoundForNewPokes(
    String activePlate,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pokes,
  ) {
    final currentPokeIds = pokes.map((poke) => poke.id).toSet();
    final knownPokeIds = _knownPokeIdsByPlate.putIfAbsent(
      activePlate,
      () => <String>{},
    );
    if (_initializedPokePlates.add(activePlate)) {
      knownPokeIds.addAll(currentPokeIds);
      return;
    }

    final hasNewPokes = currentPokeIds.difference(knownPokeIds).isNotEmpty;
    knownPokeIds
      ..retainAll(currentPokeIds)
      ..addAll(currentPokeIds);
    if (hasNewPokes) unawaited(_playPokeSound());
  }

  Future<void> _playPokeSound() async {
    try {
      await _pokeAudioPlayer.play(AssetSource('audio/poke_audio.mp3'));
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Unable to play incoming poke sound.',
        name: 'FirestorePokeService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> acknowledgePoke({
    required String activePlate,
    required String pokeId,
  }) async {
    final countSnapshot = await _firestore
        .collection('poke_counts')
        .doc(activePlate)
        .get();
    final currentCount = countSnapshot.data()?['count'];
    final count = currentCount is num
        ? (currentCount.toInt() - 1).clamp(0, 1 << 31)
        : 0;
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('pokes').doc(pokeId));
    batch.set(_firestore.collection('poke_counts').doc(activePlate), {
      'count': count,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> clearAllPokesForPlate(String activePlate) async {
    if (activePlate.isEmpty) return;
    final snapshot = await _firestore
        .collection('pokes')
        .where('toPlate', isEqualTo: activePlate)
        .get();
    final batch = _firestore.batch();
    for (final poke in snapshot.docs) {
      if (poke.data()['recordType'] != 'ride') {
        batch.delete(poke.reference);
      }
    }
    batch.set(_firestore.collection('poke_counts').doc(activePlate), {
      'count': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
