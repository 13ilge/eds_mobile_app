import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/eds_point.dart';
import '../models/shared_point.dart';
import '../models/community_point.dart';
import 'eds_storage_service.dart';
import 'eds_geofence_service.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _myUid => _auth.currentUser!.uid;
  String get _myName => _auth.currentUser!.displayName ?? 'Kullanıcı';

  Future<bool> _isDuplicate(EdsPoint point) async {
    final existingPoints = await EdsStorageService().loadCustomPoints();
    return existingPoints.any((existing) =>
        existing.startLatitude == point.startLatitude &&
        existing.startLongitude == point.startLongitude &&
        existing.endLatitude == point.endLatitude &&
        existing.endLongitude == point.endLongitude);
  }


  Future<void> shareWithFriend(EdsPoint point, String targetUid, String targetName) async {
    await _firestore.collection('shared_points').add(SharedPoint(
      id: '',
      ownerUid: _myUid,
      ownerName: _myName,
      targetUid: targetUid,
      edsPoint: point,
      createdAt: DateTime.now(),
      isPublic: false,
    ).toFirestore());
  }

  Stream<List<SharedPoint>> getIncomingSharesStream() {
    return _firestore
        .collection('shared_points')
        .where('targetUid', isEqualTo: _myUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SharedPoint.fromFirestore(doc)).toList());
  }

  Future<void> acceptShare(SharedPoint share) async {
    if (await _isDuplicate(share.edsPoint)) {
      await _firestore.collection('shared_points').doc(share.id).delete();
      throw Exception('Bu nokta zaten listenizde mevcut.');
    }

    final newPoint = EdsPoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: share.edsPoint.name,
      startLatitude: share.edsPoint.startLatitude,
      startLongitude: share.edsPoint.startLongitude,
      endLatitude: share.edsPoint.endLatitude,
      endLongitude: share.edsPoint.endLongitude,
      isBidirectional: share.edsPoint.isBidirectional,
      speedLimit: share.edsPoint.speedLimit,
    );

    await EdsStorageService().saveCustomPoint(newPoint);
    await EdsGeofenceService().reloadPoints();

    await _firestore.collection('shared_points').doc(share.id).delete();
  }

  Future<void> rejectShare(String shareId) async {
    await _firestore.collection('shared_points').doc(shareId).delete();
  }


  String _calculateGeoHash(double lat, double lng) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    const int precision = 4;

    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    final StringBuffer geohash = StringBuffer();

    while (geohash.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (lng > mid) {
          ch |= (1 << (4 - bit));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat > mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        geohash.write(base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return geohash.toString();
  }

  Future<void> shareWithCommunity(EdsPoint point, String region) async {
    final geoHash = _calculateGeoHash(
      point.startLatitude,
      point.startLongitude,
    );

    await _firestore.collection('community_points').add(CommunityPoint(
      id: '',
      ownerUid: _myUid,
      ownerName: _myName,
      edsPoint: point,
      upvotes: 0,
      region: region.toLowerCase(),
      geoHash: geoHash,
      createdAt: DateTime.now(),
    ).toFirestore());
  }

  Future<List<CommunityPoint>> getCommunityPoints({
    required String region,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('community_points')
        .where('region', isEqualTo: region.toLowerCase())
        .orderBy('upvotes', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => CommunityPoint.fromFirestore(doc))
        .toList();
  }

  Future<void> upvoteCommunityPoint(String pointId) async {
    final voteDoc = _firestore
        .collection('community_points')
        .doc(pointId)
        .collection('votes')
        .doc(_myUid);

    final exists = await voteDoc.get();
    if (exists.exists) return; // Zaten oy verilmiş

    final batch = _firestore.batch();
    batch.set(voteDoc, {'votedAt': FieldValue.serverTimestamp()});
    batch.update(
      _firestore.collection('community_points').doc(pointId),
      {'upvotes': FieldValue.increment(1)},
    );
    await batch.commit();
  }

  Future<void> removeUpvote(String pointId) async {
    final voteDoc = _firestore
        .collection('community_points')
        .doc(pointId)
        .collection('votes')
        .doc(_myUid);

    final exists = await voteDoc.get();
    if (!exists.exists) return; // Zaten oy yok

    final batch = _firestore.batch();
    batch.delete(voteDoc);
    batch.update(
      _firestore.collection('community_points').doc(pointId),
      {'upvotes': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  Future<bool> hasUpvoted(String pointId) async {
    final doc = await _firestore
        .collection('community_points')
        .doc(pointId)
        .collection('votes')
        .doc(_myUid)
        .get();
    return doc.exists;
  }

  Future<void> importCommunityPoint(CommunityPoint point) async {
    if (await _isDuplicate(point.edsPoint)) {
      throw Exception('Bu nokta zaten listenizde mevcut.');
    }

    final newPoint = EdsPoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: point.edsPoint.name,
      startLatitude: point.edsPoint.startLatitude,
      startLongitude: point.edsPoint.startLongitude,
      endLatitude: point.edsPoint.endLatitude,
      endLongitude: point.edsPoint.endLongitude,
      isBidirectional: point.edsPoint.isBidirectional,
      speedLimit: point.edsPoint.speedLimit,
    );

    await EdsStorageService().saveCustomPoint(newPoint);
    await EdsGeofenceService().reloadPoints();
    debugPrint('Topluluk noktası yerel listeye eklendi: ${newPoint.name}');
  }
}
