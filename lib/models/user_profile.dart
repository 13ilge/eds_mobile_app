import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final int friendCount;
  
  // Phase 3: Gamification Fields
  final double averageScore;
  final int totalSessions;
  final Map<String, String> earnedBadges; // { "compliance": "bronze", "accuracy": "gold" }
  final List<String> displayedBadges; // ["compliance", "accuracy"]
  final bool isLeaderboardHidden;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    this.friendCount = 0,
    this.averageScore = 0.0,
    this.totalSessions = 0,
    this.earnedBadges = const {},
    this.displayedBadges = const [],
    this.isLeaderboardHidden = false,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      friendCount: data['friendCount'] ?? 0,
      averageScore: (data['averageScore'] ?? 0.0).toDouble(),
      totalSessions: data['totalSessions'] ?? 0,
      earnedBadges: Map<String, String>.from(data['earnedBadges'] ?? {}),
      displayedBadges: List<String>.from(data['displayedBadges'] ?? []),
      isLeaderboardHidden: data['isLeaderboardHidden'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'isPro': false, // Sunucu tarafı için — istemci asla okumaz
      'createdAt': FieldValue.serverTimestamp(),
      'friendCount': friendCount,
      'averageScore': averageScore,
      'totalSessions': totalSessions,
      'earnedBadges': earnedBadges,
      'displayedBadges': displayedBadges,
      'isLeaderboardHidden': isLeaderboardHidden,
    };
  }
}
