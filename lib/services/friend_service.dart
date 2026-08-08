import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friendship.dart';
import '../models/user_profile.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _myUid => _auth.currentUser!.uid;
  String get _myName => _auth.currentUser!.displayName ?? 'Kullanıcı';

  Future<UserProfile?> searchUserByEmail(String email) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return UserProfile.fromFirestore(query.docs.first);
  }

  Future<void> sendFriendRequest(String targetUid, String targetName) async {
    if (targetUid == _myUid) return;

    // Targeted queries: check both directions, max 2 reads (F2 optimization)
    final results = await Future.wait([
      _firestore.collection('friendships')
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: targetUid)
          .limit(1)
          .get(),
      _firestore.collection('friendships')
          .where('fromUid', isEqualTo: targetUid)
          .where('toUid', isEqualTo: _myUid)
          .limit(1)
          .get(),
    ]);

    final alreadyExists = results.any((snap) => snap.docs.isNotEmpty);

    if (alreadyExists) {
      throw Exception('Bu kullanıcıyla zaten bir arkadaşlık isteği veya bağlantı mevcut.');
    }

    await _firestore.collection('friendships').add(Friendship(
      id: '',
      fromUid: _myUid,
      fromName: _myName,
      toUid: targetUid,
      toName: targetName,
      status: 'pending',
      createdAt: DateTime.now(),
      participants: [_myUid, targetUid],
    ).toFirestore());
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    final batch = _firestore.batch();
    final docRef = _firestore.collection('friendships').doc(friendshipId);

    batch.update(docRef, {'status': 'accepted'});

    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final fromUid = data['fromUid'] as String;
      final toUid = data['toUid'] as String;

      batch.update(
        _firestore.collection('users').doc(fromUid),
        {'friendCount': FieldValue.increment(1)},
      );
      batch.update(
        _firestore.collection('users').doc(toUid),
        {'friendCount': FieldValue.increment(1)},
      );
    }

    await batch.commit();
  }

  Future<void> rejectFriendRequest(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).delete();
  }

  Future<void> removeFriend(String friendshipId) async {
    final docRef = _firestore.collection('friendships').doc(friendshipId);
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      final fromUid = data['fromUid'] as String;
      final toUid = data['toUid'] as String;

      final batch = _firestore.batch();
      batch.delete(docRef);

      batch.update(
        _firestore.collection('users').doc(fromUid),
        {'friendCount': FieldValue.increment(-1)},
      );
      batch.update(
        _firestore.collection('users').doc(toUid),
        {'friendCount': FieldValue.increment(-1)},
      );

      await batch.commit();
    }
  }

  Stream<List<Friendship>> getFriendsStream() {
    return _firestore
        .collection('friendships')
        .where('participants', arrayContains: _myUid)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friendship.fromFirestore(doc)).toList());
  }

  Stream<List<Friendship>> getPendingRequestsStream() {
    return _firestore
        .collection('friendships')
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friendship.fromFirestore(doc)).toList());
  }
}
