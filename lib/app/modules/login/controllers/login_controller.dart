import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/push_service.dart';
import 'package:transport/app/data/services/clock_in_service.dart';

import 'package:transport/app/core/config/app_config.dart';
import 'package:transport/app/core/utils/app_logger.dart';

class LoginController extends GetxController {
  // Inputs
  final phoneController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  // State Variables
  final RxBool isLoading = false.obs;
  final RxString selectedCountryCode = '+91'.obs;
  
  /// Global reactive mock mode state
  RxBool get isMockMode => AppConfig.isMockMode;

  @override
  void onInit() {
    super.onInit();
    AppLogger.d('Firebase Auth mode: ${isMockMode.value ? "MOCK" : "LIVE"}');
  }

  /// Change application language
  void changeLanguage(String langCode) {
    AppConfig.changeLanguage(langCode);
  }

  /// Toggle app mode globally between LIVE and MOCK
  void toggleMockMode() {
    AppConfig.toggleMode();
    AppSnackBar.showInfo(
      title: 'Mode Switched',
      message: AppConfig.isMock
          ? 'Switched to MOCK MODE (Test OTP: 123456)'
          : 'Switched to LIVE MODE (Real Firebase SMS)',
    );
  }

  // Send Verification Code (Phone Number)
  Future<void> sendOtp() async {
    if (!formKey.currentState!.validate()) return;

    // Build international E.164 phone number
    final digits = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final phone = '${selectedCountryCode.value}$digits';
    isLoading.value = true;
    AppPopup.showLoading(message: 'Checking account status...');

    // SECURITY GUARD: Check if account exists and was created by Admin
    final firebaseService = Get.find<FirebaseService>();
    final userData = await firebaseService.getUserData(phone);

    if (userData == null) {
      AppPopup.hideLoading();
      isLoading.value = false;
      AppSnackBar.showError(
        title: 'Access Denied 🚫',
        message:
            'Your account has not been created yet.\nPlease contact your administrator.',
      );
      return;
    }

    final bool isDeleted = userData['isDeleted'] == true;
    if (isDeleted) {
      AppPopup.hideLoading();
      isLoading.value = false;
      AppSnackBar.showError(
        title: 'Access Denied 🚫',
        message:
            'This account is no longer available.\nPlease contact your administrator.',
      );
      return;
    }

    final bool isActive = userData['isActive'] as bool? ?? true;
    if (!isActive) {
      AppPopup.hideLoading();
      isLoading.value = false;
      AppSnackBar.showError(
        title: 'Account Inactive 🚫',
        message:
            'Your account is currently inactive.\nPlease contact your administrator.',
      );
      return;
    }

    AppPopup.showLoading(message: 'Requesting OTP...');

    if (isMockMode.value) {
      // Mock Authentication flow
      await Future.delayed(const Duration(seconds: 2));
      AppPopup.hideLoading();
      isLoading.value = false;
      
      // Navigate to OTP page passing parameters
      Get.toNamed(
        Routes.OTP_VERIFICATION,
        arguments: {
          'phone': phone,
          'isMock': true,
          'verificationId': 'mock-verification-id'
        },
      );
      
      AppSnackBar.showSuccess(
        title: 'SMS Sent (Mock Mode)',
        message: 'Mock verification code is sent! Enter code: 123456',
      );
    } else {
      // Actual Firebase Authentication
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) {
            // If instant verification happens, we proceed directly
            _signInWithCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            AppLogger.e('Firebase Phone Auth Failed: [${e.code}] ${e.message}', e);
            AppPopup.hideLoading();
            isLoading.value = false;
            AppSnackBar.showError(
              title: 'Verification Failed (${e.code})',
              message: e.message ?? 'Unknown error occurred.',
            );
          },
          codeSent: (String verificationId, int? resendToken) {
            AppPopup.hideLoading();
            isLoading.value = false;
            
            // Navigate to OTP page passing real verificationId
            Get.toNamed(
              Routes.OTP_VERIFICATION,
              arguments: {
                'phone': phone,
                'isMock': false,
                'verificationId': verificationId
              },
            );
            
            AppSnackBar.showSuccess(
              title: 'OTP Sent',
              message: 'Verification code sent to $phone',
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        AppPopup.hideLoading();
        isLoading.value = false;
        AppSnackBar.showError(
          title: 'Error',
          message: 'Firebase verification exception: ${e.toString()}',
        );
      }
    }
  }

  // Instant sign in helper — checks role from Firestore before routing
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        final phoneInput = user.phoneNumber ?? phoneController.text.trim();
        final session = Get.find<SessionService>();
        final firebaseService = Get.find<FirebaseService>();

        // Lookup user or driver from Firestore
        final userData = await firebaseService.getUserData(phoneInput);
        final rawPhoneVal = (userData?['phone'] ?? userData?['phoneNumber'] ?? userData?['driverPhone'] ?? phoneInput).toString();
        final docPhone = SessionService.normalizePhone(rawPhoneVal);
        final role = (userData?['role'] ?? 'driver').toString().toLowerCase();
        final name = (userData?['name'] ?? userData?['driverName'] ?? 'Driver').toString();
        final avatarUrl = userData?['avatarUrl']?.toString();

        if (userData != null) {
          final existingUid = userData['uid']?.toString();
          if (existingUid == null || existingUid.isEmpty || existingUid != user.uid) {
            userData['uid'] = user.uid;
            await firebaseService.linkUserUid(docPhone, user.uid, userData);
          }
        }

        await session.setSession(
          phone: docPhone,
          uid: user.uid,
          name: name,
          role: role,
          avatarUrl: avatarUrl,
        );

        if (Get.isRegistered<PushService>()) {
          Get.find<PushService>().registerForUser();
        }

        if (role == 'admin') {
          Get.offAllNamed(Routes.ADMIN_HOME);
        } else {
          final clockInService = Get.find<ClockInService>();
          Get.offAllNamed(clockInService.getInitialRoute());
        }
        AppSnackBar.showSuccess(title: 'Welcome', message: 'Logged in as ${role.toUpperCase()}!');
      }
    } catch (e) {
      AppSnackBar.showError(
        title: 'Authentication Error',
        message: e.toString(),
      );
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
