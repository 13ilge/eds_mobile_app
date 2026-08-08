import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status; // "pending", "accepted", "rejected"
  final DateTime createdAt;
  final List<String> participants;

  const Friendship({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
    required this.participants,
  });

  factory Friendship.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Friendship(
      id: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'] ?? '',
      toUid: data['toUid'] ?? '',
      toName: data['toName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: List<String>.from(data['participants'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'participants': participants,
    };
  }

  String friendNameFor(String myUid) {
    return myUid == fromUid ? toName : fromName;
  }

  String friendUidFor(String myUid) {
    return myUid == fromUid ? toUid : fromUid;
  }
}
