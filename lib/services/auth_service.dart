import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/user_profile.dart';
import '../services/eds_storage_service.dart';
import '../services/eds_geofence_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthService(this._auth, this._firestore, this._googleSignIn);

  Future<void> _syncUserToFirestore(User user, {String? displayName}) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      final newUser = UserProfile(
        uid: user.uid,
        displayName: displayName ?? user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      await userRef.set(newUser.toFirestore());
    }
  }

  Future<User?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await _syncUserToFirestore(user, displayName: displayName);
        await Purchases.logIn(user.uid);
        EdsStorageService().clearCache();
        await EdsGeofenceService().reloadPoints();
        await user.reload();
        return _auth.currentUser;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _syncUserToFirestore(userCredential.user!);
        await Purchases.logIn(userCredential.user!.uid);
        EdsStorageService().clearCache();
        await EdsGeofenceService().reloadPoints();
      }
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Kullanıcı akışı iptal etti

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _syncUserToFirestore(userCredential.user!);
        await Purchases.logIn(userCredential.user!.uid);
        EdsStorageService().clearCache();
        await EdsGeofenceService().reloadPoints();
      }
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await Purchases.logOut();
    
    EdsStorageService().clearCache();
    await EdsGeofenceService().reloadPoints();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      
      await _firestore.collection('users').doc(uid).delete();
      
      await user.delete();
    }
  }
}
