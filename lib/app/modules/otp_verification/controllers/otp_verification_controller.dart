import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';

import 'package:transport/app/core/utils/app_logger.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/clock_in_service.dart';

class OtpVerificationController extends GetxController {
  final _session = Get.find<SessionService>();

  // Inputs
  final otpController = TextEditingController();

  // Route Parameters
  late final String rawPhone;
  late final String maskedPhone;
  late final bool isMock;
  late String verificationId;

  // States
  final RxInt resendTimer = 30.obs;
  final RxBool isLoading = false.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    
    // Parse navigation arguments
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    rawPhone = args['phone'] as String? ?? '+919876543210';
    isMock = args['isMock'] as bool? ?? true;
    verificationId = args['verificationId'] as String? ?? '';

    // Create masked phone representation (e.g. ******9012)
    if (rawPhone.length > 4) {
      final endDigits = rawPhone.substring(rawPhone.length - 4);
      maskedPhone = '******$endDigits';
    } else {
      maskedPhone = rawPhone;
    }

    _startResendTimer();
  }

  // Verify Code Entry
  Future<void> verifyOtp() async {
    final code = otpController.text.trim();
    if (code.length < 6) {
      AppSnackBar.showWarning(title: 'Validation', message: 'Please enter the 6-digit code.');
      return;
    }

    isLoading.value = true;
    AppPopup.showLoading(message: 'Verifying Identity...');

    if (isMock) {
      // Mock validation
      await Future.delayed(const Duration(seconds: 2));
      AppPopup.hideLoading();
      isLoading.value = false;

      if (code == '123456') {
        await _handleUserLoginOrSignup(rawPhone);
      } else {
        AppSnackBar.showError(title: 'Invalid Code', message: 'Mock verification code mismatch. Enter: 123456');
      }
    } else {
      // Firebase Verification
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCredential.user;

        AppPopup.hideLoading();
        isLoading.value = false;

        if (user != null) {
          await _handleUserLoginOrSignup(user.phoneNumber ?? rawPhone);
        }
      } catch (e) {
        AppPopup.hideLoading();
        isLoading.value = false;
        AppSnackBar.showError(
          title: 'Verification Error',
          message: 'The OTP entered is incorrect or expired.',
        );
      }
    }
  }

  Future<void> _handleUserLoginOrSignup(String phone) async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      final userData = await firebaseService.getUserData(phone);

      if (userData == null) {
        // ── ACCESS DENIED: phone not pre-registered by any Admin ──────────────
        await _denyAccess(
          'Account Not Found',
          'Your account has not been created yet.\nPlease contact your administrator.',
        );
        return;
      }

      // ── Validate driver status ──────────────────────────────────────────────
      final isDeleted = userData['isDeleted'] == true;
      if (isDeleted) {
        await _denyAccess(
          'Account Unavailable',
          'This account is no longer available.\nPlease contact your administrator.',
        );
        return;
      }

      final isActive = userData['isActive'] as bool? ?? true; // default active
      if (!isActive) {
        await _denyAccess(
          'Account Deactivated',
          'Your account has been deactivated.\nPlease contact your administrator.',
        );
        return;
      }

      // ── Existing, active user — proceed ────────────────────────────────────
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // Use the EXACT Firestore document ID as the canonical key.
      // normalizePhone() strips '+', causing checkIn/checkOut to write to a
      // different doc than the one the admin panel watches. Using docId ensures
      // availability updates land on the correct document.
      final docId = (userData['docId'] as String?)?.isNotEmpty == true
          ? userData['docId'] as String
          : SessionService.normalizePhone(
              (userData['phone'] ?? userData['phoneNumber'] ?? userData['driverPhone'] ?? phone).toString());

      // 1. Link UID if missing or changed
      final existingUid = userData['uid']?.toString();
      if (currentUid != null && currentUid.isNotEmpty && (existingUid == null || existingUid.isEmpty || existingUid != currentUid)) {
        userData['uid'] = currentUid;
        await firebaseService.linkUserUid(docId, currentUid, userData);
      }

      // 2. Read role, name, avatar
      final role = (userData['role'] ?? 'driver').toString().toLowerCase();
      final name = (userData['name'] ?? userData['driverName'] ?? 'Driver').toString();
      final avatarUrl = userData['avatarUrl']?.toString();

      // 3. Create user session — phone stored as docId so ownerKey matches Firestore
      await _session.setSession(
        phone: docId,
        uid: currentUid ?? existingUid,
        name: name,
        role: role,
        avatarUrl: avatarUrl,
      );

      // 4. Navigate directly to Dashboard or Onboarding / Clock In
      if (role == 'admin') {
        Get.offAllNamed(Routes.ADMIN_HOME);
      } else {
        final clockInService = Get.find<ClockInService>();
        Get.offAllNamed(clockInService.getInitialRoute());
      }
      AppSnackBar.showSuccess(
        title: 'Welcome Back',
        message: 'Logged in as $name!',
      );
    } catch (e) {
      AppSnackBar.showError(title: 'Authentication Error', message: e.toString());
    }
  }

  /// Signs the user out of Firebase Auth and clears the local session,
  /// then shows a persistent access-denied dialog on the login screen.
  Future<void> _denyAccess(String title, String message) async {
    // Sign out Firebase Auth silently so the user can't re-enter on next launch
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _session.clear();

    // Navigate back to login first, then show the error dialog on top
    Get.offAllNamed(Routes.LOGIN);

    // Small delay so the Login route has time to settle before the dialog opens
    await Future.delayed(const Duration(milliseconds: 300));

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Get.back(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // Resend OTP
  Future<void> resendOtp() async {
    if (resendTimer.value > 0) return;

    isLoading.value = true;
    AppPopup.showLoading(message: 'Resending code...');

    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 1500));
      AppPopup.hideLoading();
      isLoading.value = false;
      _startResendTimer();
      AppSnackBar.showSuccess(
        title: 'SMS Sent (Mock Mode)',
        message: 'Mock verification code resent! Enter code: 123456',
      );
    } else {
      // Trigger Firebase Phone Auth Resend
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: rawPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto login — check role before routing
            try {
              final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
              if (userCredential.user != null) {
                AppPopup.hideLoading();
                await _handleUserLoginOrSignup(userCredential.user!.phoneNumber ?? rawPhone);
              }
            } catch (e) {
              AppPopup.hideLoading();
              AppSnackBar.showError(title: 'Auto Login Error', message: e.toString());
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            AppLogger.e('Firebase Phone Auth Resend Failed: [${e.code}] ${e.message}', e);
            AppPopup.hideLoading();
            isLoading.value = false;
            AppSnackBar.showError(title: 'Resend Failed (${e.code})', message: e.message ?? '');
          },
          codeSent: (String newVerificationId, int? resendToken) {
            verificationId = newVerificationId;
            AppPopup.hideLoading();
            isLoading.value = false;
            _startResendTimer();
            AppSnackBar.showSuccess(title: 'OTP Resent', message: 'SMS verification sent.');
          },
          codeAutoRetrievalTimeout: (String id) {
            verificationId = id;
          },
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        AppPopup.hideLoading();
        isLoading.value = false;
        AppSnackBar.showError(title: 'Error', message: e.toString());
      }
    }
  }

  // Navigate back to Login view
  void changeMobileNumber() {
    Get.back();
  }

  // Timer Countdown
  void _startResendTimer() {
    resendTimer.value = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value > 0) {
        resendTimer.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    otpController.dispose();
    super.onClose();
  }
}
