import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final googleSignInProvider = Provider<google_sign_in.GoogleSignIn>((ref) {
  return google_sign_in.GoogleSignIn();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(firebaseAuthProvider),
    FirebaseFirestore.instance, // avoid circular dependency with user_profile_provider
    ref.watch(googleSignInProvider),
  );
});
