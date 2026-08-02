import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/routes/app_pages.dart';

class SplashController extends GetxController {
  final _session = Get.find<SessionService>();

  final RxDouble loadingProgress = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _startProgressLoader();
  }

  void _startProgressLoader() {
    // Simulate loading progress bar
    const totalSteps = 30;
    var currentStep = 0;

    // Periodically update progress until 3 seconds pass
    const duration = Duration(milliseconds: 100);

    Future.doWhile(() async {
      await Future.delayed(duration);
      currentStep++;
      loadingProgress.value = currentStep / totalSteps;

      if (currentStep >= totalSteps) {
        _checkLoginStatus();
        return false;
      }
      return true;
    });
  }

  void _checkLoginStatus() {
    // Verify BOTH the local persisted session AND the live Firebase Auth state.
    // If the local session says "logged in" but Firebase Auth has no user
    // (e.g. token expired, session revoked, app data partially cleared),
    // treat it as logged-out to avoid entering a broken home screen.
    final hasLocalSession = _session.isLoggedIn;
    bool hasFirebaseUser = false;
    try {
      hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      // Firebase not initialised (test environment) — fall through to
      // local-session-only check so the splash still works.
    }

    if (hasLocalSession && hasFirebaseUser) {
      // Fully authenticated — route based on role.
      if (_session.isAdmin) {
        Get.offAllNamed(Routes.ADMIN_HOME);
      } else {
        Get.offAllNamed(Routes.HOME);
      }
    } else {
      // Either no local session or Firebase Auth disagrees — clear any stale
      // local state and send to login.
      if (hasLocalSession && !hasFirebaseUser) {
        // Stale local session — clear it.
        _session.clear();
      }
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}

