import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/routes/app_pages.dart';

/// Centralised Firebase Auth wrapper.
///
/// Responsibilities:
/// 1. Listen to [authStateChanges] — when the user signs out (or the server
///    revokes the session), automatically clear the local [SessionService] and
///    redirect to the login screen.
/// 2. Provide a single [signOut] entry point used by both the driver and admin
///    logout flows, so session cleanup is never missed.
/// 3. Expose [currentUser] and [isAuthenticated] for route guards and UI.
class AuthService extends GetxService {
  final Rx<User?> _firebaseUser = Rx<User?>(null);
  StreamSubscription<User?>? _authSub;

  /// Whether there is a live Firebase Auth session.
  bool get isAuthenticated => _firebaseUser.value != null;

  /// The currently signed-in Firebase user, or null.
  User? get currentUser => _firebaseUser.value;

  Future<AuthService> init() async {
    // Seed with the current user (may be null if never signed in).
    _firebaseUser.value = FirebaseAuth.instance.currentUser;

    // Listen for auth state changes (sign-in, sign-out, token revocation).
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (e) {
        debugPrint('[AuthService] authStateChanges error: $e');
      },
    );

    return this;
  }

  void _onAuthStateChanged(User? user) {
    final previous = _firebaseUser.value;
    _firebaseUser.value = user;

    if (previous != null && user == null) {
      // User was signed in but is now signed out (session expired, revoked,
      // or explicit sign-out from another device / the Firebase Console).
      debugPrint('[AuthService] Session lost — redirecting to login.');
      _clearAndRedirect();
    }
  }

  /// Unified sign-out used by both driver and admin flows.
  ///
  /// 1. Signs out of Firebase Auth.
  /// 2. Clears the local [SessionService] (all persisted keys).
  /// 3. Navigates to the login screen, removing the entire back-stack.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[AuthService] Firebase signOut error: $e');
    }
    await _clearSession();
    Get.offAllNamed(Routes.LOGIN);
  }

  /// Internal: clear local session without navigation (used by the
  /// auth-state listener which handles redirect separately).
  Future<void> _clearAndRedirect() async {
    await _clearSession();
    // Only redirect if we're not already on the login or splash screen.
    final currentRoute = Get.currentRoute;
    if (currentRoute != Routes.LOGIN && currentRoute != Routes.SPLASH) {
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  Future<void> _clearSession() async {
    try {
      await Get.find<SessionService>().clear();
    } catch (_) {}
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
