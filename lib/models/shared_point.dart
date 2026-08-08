import 'package:cloud_firestore/cloud_firestore.dart';
import 'eds_point.dart';

class SharedPoint {
  final String id;
  final String ownerUid;
  final String ownerName;
  final String? targetUid;
  final EdsPoint edsPoint;
  final DateTime createdAt;
  final bool isPublic;

  const SharedPoint({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    this.targetUid,
    required this.edsPoint,
    required this.createdAt,
    this.isPublic = false,
  });

  factory SharedPoint.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SharedPoint(
      id: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      targetUid: data['targetUid'],
      edsPoint: EdsPoint.fromJson(
        Map<String, dynamic>.from(data['edsPoint'] ?? {}),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: data['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'targetUid': targetUid,
      'edsPoint': edsPoint.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'isPublic': isPublic,
    };
  }
}
