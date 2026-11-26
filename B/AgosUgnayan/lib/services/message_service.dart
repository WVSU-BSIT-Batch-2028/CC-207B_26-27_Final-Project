// Chats between buyers and farmers. A chat lives at chats/{chatId} and its
// messages at chats/{chatId}/messages. We use Firestore streams so new
// messages appear right away without refreshing.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';

/// Opening chats, listening to them and sending messages.
class MessageService {
  CollectionReference<Map<String, dynamic>> get _chats =>
      FirebaseFirestore.instance.collection('chats');

  /// The chat id for two users: both ids sorted and joined with "_".
  /// Sorting means A→B and B→A give the same id, so each pair of users has
  /// exactly one chat.
  static String chatIdFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  /// Makes sure the chat between me and the other user exists, and returns
  /// its id. Called by the "Message farmer" / "Message buyer" buttons.
  Future<String> openChat({
    required String myId,
    required String myName,
    required String otherId,
    required String otherName,
  }) {
    return runSafely('open chat', () async {
      final chatId = chatIdFor(myId, otherId);
      // merge: true keeps the last message if the chat already exists.
      await _chats.doc(chatId).set({
        'participants': [myId, otherId],
        'names': {myId: myName, otherId: otherName},
      }, SetOptions(merge: true));
      return chatId;
    });
  }

  /// Live list of my chats. Sorted newest first in Dart (no index needed).
  Stream<List<Chat>> watchChats(String myId) {
    return _chats.where('participants', arrayContains: myId).snapshots().map((
      snapshot,
    ) {
      final chats = snapshot.docs
          .map((doc) => Chat.fromMap(doc.id, doc.data()))
          // Hide chats that were opened but never used.
          .where((chat) => chat.lastMessage.isNotEmpty)
          .toList();
      chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return chats;
    });
  }

  /// Live list of the newest [limit] messages in a chat, newest first.
  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 50}) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Sends a message and updates the chat's "last message" in one batch, so
  /// both writes succeed or both fail.
  /// Remembers that [myId] has read [chatId] now, so the inbox stops
  /// showing it as unread. Failing here is not important, so errors are
  /// only logged.
  Future<void> markRead(String chatId, String myId) async {
    try {
      await _chats.doc(chatId).update({
        'readAt.$myId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('mark chat read failed', e);
    }
  }

  Future<void> send({
    required String chatId,
    required String senderId,
    required String text,
  }) {
    return runSafely('send message', () {
      final chatRef = _chats.doc(chatId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chatRef.collection('messages').doc(), {
        'senderId': senderId,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(chatRef, {
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId, // for the unread dot in the inbox
        'readAt.$senderId': FieldValue.serverTimestamp(),
      });
      return batch.commit();
    });
  }
}
