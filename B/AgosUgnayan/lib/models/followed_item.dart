// Something a buyer follows: a crop listing or a farmer. Saved in Firestore
// at users/{uid}/following/{targetId}.

import 'firestore_date.dart';

/// The two kinds of things a buyer can follow.
class FollowType {
  FollowType._();

  static const String listing = 'listing';
  static const String farmer = 'farmer';
}

/// One followed listing or farmer. We save a title and subtitle with it, so
/// the Following screen can show the list without loading every listing.
class FollowedItem {
  const FollowedItem({
    required this.targetId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  final String targetId; // listing id or farmer's user id
  final String type; // one of FollowType
  final String title; // e.g. "Tomato · 50 kg" or "Mang Pedro"
  final String subtitle; // e.g. "₱45.00/kg · Leon" or "Leon"
  final DateTime createdAt;

  factory FollowedItem.fromMap(String id, Map<String, dynamic> data) {
    return FollowedItem(
      targetId: id,
      type: data['type'] as String? ?? FollowType.listing,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      createdAt: readDate(data['createdAt']),
    );
  }
}
