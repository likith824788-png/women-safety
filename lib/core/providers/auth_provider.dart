import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';

class AuthState {
  final UserProfile? userProfile;
  final bool isAuthenticated;
  final bool isProfileComplete;
  final bool isLoading;
  final String? error;

  AuthState({
    this.userProfile,
    this.isAuthenticated = false,
    this.isProfileComplete = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserProfile? userProfile,
    bool? isAuthenticated,
    bool? isProfileComplete,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userProfile: userProfile ?? this.userProfile,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _restoreSession();
  }

  /// On app start, check if user is already logged in via Firebase
  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true);
    final user = FirebaseService.currentUser;
    if (user != null) {
      await _loadAndSetProfile(user);
    } else {
      state = AuthState(isLoading: false);
    }
  }

  /// Load profile from Firestore and update state
  Future<void> _loadAndSetProfile(User user) async {
    final profile = await FirebaseService.loadProfile(user.uid);
    final isComplete = profile != null &&
        profile.name.isNotEmpty &&
        profile.dateOfBirth.isNotEmpty &&
        profile.securityPin.isNotEmpty;

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      isProfileComplete: isComplete,
      userProfile: profile ??
          UserProfile(
            uid: user.uid,
            name: user.displayName ?? '',
            phone: user.phoneNumber ?? '',
            email: user.email,
            dateOfBirth: '',
            securityPin: '',
          ),
    );
  }

  // ── Email + Password Sign Up ────────────────────────────────────────────
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await FirebaseService.signUpWithEmail(
        email: email,
        password: password,
      );
      if (cred?.user != null) {
        await _loadAndSetProfile(cred!.user!);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Email + Password Sign In ────────────────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await FirebaseService.signInWithEmail(
        email: email,
        password: password,
      );
      if (cred?.user != null) {
        await _loadAndSetProfile(cred!.user!);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Google Sign In ──────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await FirebaseService.signInWithGoogle();
      if (cred?.user != null) {
        await _loadAndSetProfile(cred!.user!);
      } else {
        // User cancelled the Google sign-in
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Save Profile ────────────────────────────────────────────────────────
  Future<void> saveProfile(UserProfile profile) async {
    final uid = FirebaseService.currentUser?.uid ?? profile.uid;
    final finalProfile = profile.copyWith();
    await FirebaseService.saveProfile(uid, finalProfile);
    state = state.copyWith(
      isProfileComplete: true,
      userProfile: finalProfile,
    );
  }

  // ── Sign Out ────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await FirebaseService.signOut();
    state = AuthState();
  }

  // ── Password Reset ──────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await FirebaseService.sendPasswordReset(email);
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
