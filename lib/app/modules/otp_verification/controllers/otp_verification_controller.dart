import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';

class OtpVerificationController extends GetxController {
  final _storage = Get.find<StorageService>();

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
    if (code.length < 4) {
      AppSnackBar.showWarning(title: 'Validation', message: 'Please enter the 4-digit code.');
      return;
    }

    isLoading.value = true;
    AppPopup.showLoading(message: 'Verifying Identity...');

    if (isMock) {
      // Mock validation
      await Future.delayed(const Duration(seconds: 2));
      AppPopup.hideLoading();
      isLoading.value = false;

      if (code == '1234') {
        _storage.write('isLoggedIn', true);
        _storage.write('userPhone', rawPhone);
        Get.offAllNamed(Routes.HOME);
        AppSnackBar.showSuccess(title: 'Welcome', message: 'Successfully logged in!');
      } else {
        AppSnackBar.showError(title: 'Invalid Code', message: 'Mock verification code mismatch. Enter: 1234');
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
          _storage.write('isLoggedIn', true);
          _storage.write('userPhone', user.phoneNumber ?? rawPhone);
          Get.offAllNamed(Routes.HOME);
          AppSnackBar.showSuccess(title: 'Welcome', message: 'Successfully logged in!');
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
        message: 'Mock verification code resent! Enter code: 1234',
      );
    } else {
      // Trigger Firebase Phone Auth Resend
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: rawPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto login
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            if (userCredential.user != null) {
              AppPopup.hideLoading();
              _storage.write('isLoggedIn', true);
              _storage.write('userPhone', rawPhone);
              Get.offAllNamed(Routes.HOME);
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            AppPopup.hideLoading();
            isLoading.value = false;
            AppSnackBar.showError(title: 'Resend Failed', message: e.message ?? '');
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
