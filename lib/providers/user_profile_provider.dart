import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return UserProfile.fromFirestore(doc);
      });
});
