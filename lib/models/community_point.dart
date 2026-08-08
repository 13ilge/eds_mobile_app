import 'package:cloud_firestore/cloud_firestore.dart';
import 'eds_point.dart';

class CommunityPoint {
  final String id;
  final String ownerUid;
  final String ownerName;
  final EdsPoint edsPoint;
  final int upvotes;
  final String region;
  final String geoHash;
  final DateTime createdAt;

  const CommunityPoint({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.edsPoint,
    this.upvotes = 0,
    required this.region,
    this.geoHash = '',
    required this.createdAt,
  });

  factory CommunityPoint.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CommunityPoint(
      id: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      edsPoint: EdsPoint.fromJson(Map<String, dynamic>.from(data['edsPoint'] ?? {})),
      upvotes: data['upvotes'] ?? 0,
      region: data['region'] ?? '',
      geoHash: data['geoHash'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'edsPoint': edsPoint.toJson(),
      'upvotes': upvotes,
      'region': region,
      'geoHash': geoHash,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
