import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile_model.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth State Stream ─────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ── Email + Password Sign Up ──────────────────────────────────────────────
  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ── Email + Password Sign In ──────────────────────────────────────────────
  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web uses popup
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        final cred = await _auth.signInWithPopup(provider);
        return cred;
      } else {
        // Mobile uses native flow
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        return cred;
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (!kIsWeb) _googleSignIn.signOut(),
    ]);
  }

  // ── Save Profile to Firestore ─────────────────────────────────────────────
  static Future<void> saveProfile(String uid, UserProfile profile) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': profile.name,
        'phone': profile.phone,
        'email': profile.email ?? '',
        'dateOfBirth': profile.dateOfBirth,
        'securityPin': profile.securityPin,
        'profileImagePath': profile.profileImagePath ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveProfile error: $e');
    }
  }

  // ── Load Profile from Firestore ───────────────────────────────────────────
  static Future<UserProfile?> loadProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      return UserProfile(
        uid: uid,
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        email: data['email'] as String?,
        dateOfBirth: data['dateOfBirth'] ?? '',
        securityPin: data['securityPin'] ?? '',
        profileImagePath: (data['profileImagePath'] as String?)?.isNotEmpty == true
            ? data['profileImagePath'] as String
            : null,
      );
    } catch (e) {
      debugPrint('Firestore loadProfile error: $e');
      return null;
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ── Error Mapper ──────────────────────────────────────────────────────────
  static String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
