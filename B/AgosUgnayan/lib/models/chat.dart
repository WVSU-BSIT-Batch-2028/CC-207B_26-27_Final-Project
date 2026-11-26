// A conversation between one buyer and one farmer (chats/{id}) and the
// messages inside it (chats/{id}/messages/{id}).

import 'firestore_date.dart';

/// One conversation, as shown in the inbox.
class Chat {
  const Chat({
    required this.id,
    required this.participants,
    required this.names,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastSenderId = '',
    this.readAt = const {},
  });

  final String id; // the two user ids, sorted and joined with "_"
  final List<String> participants;
  final Map<String, String> names; // user id -> display name
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId; // empty for chats saved before this existed
  final Map<String, DateTime> readAt; // user id -> when they last opened it

  /// True when the other person wrote last and I haven't opened it since.
  bool isUnreadFor(String myId) {
    if (lastSenderId.isEmpty || lastSenderId == myId) return false;
    final read = readAt[myId];
    return read == null || read.isBefore(lastMessageAt);
  }

  /// The id of the other person in this chat.
  String otherUserId(String myId) {
    return participants.firstWhere((id) => id != myId, orElse: () => '');
  }

  /// The name of the other person in this chat.
  String otherUserName(String myId) => names[otherUserId(myId)] ?? 'User';

  factory Chat.fromMap(String id, Map<String, dynamic> data) {
    final rawNames = data['names'] as Map<String, dynamic>? ?? {};
    return Chat(
      id: id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      names: rawNames.map((key, value) => MapEntry(key, value.toString())),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: readDate(data['lastMessageAt']),
      lastSenderId: data['lastSenderId'] as String? ?? '',
      readAt: {
        for (final entry
            in (data['readAt'] as Map<String, dynamic>? ?? {}).entries)
          entry.key: readDate(entry.value),
      },
    );
  }
}

/// One message in a chat.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.orderId = '',
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  /// For an order card (type "order"): the order's id. Empty for text.
  final String orderId;

  bool get isOrderCard => orderId.isNotEmpty;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: readDate(data['createdAt']),
      orderId: data['type'] == 'order' ? data['orderId'] as String? ?? '' : '',
    );
  }
}
