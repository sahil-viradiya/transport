import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/app/data/services/storage_service.dart';

class LoginController extends GetxController {
  // Inputs
  final phoneController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  // State Variables
  final RxBool isLoading = false.obs;
  final RxBool isMockMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Force mock mode for local testing to bypass Firebase reCAPTCHA and console restrictions
    isMockMode.value = true;
    print('Mock Mode forced active for developer testing.');
  }

  // Send Verification Code (Phone Number)
  Future<void> sendOtp() async {
    if (!formKey.currentState!.validate()) return;

    final phone = phoneController.text.trim();
    isLoading.value = true;
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
        message: 'Mock verification code is sent! Enter code: 1234',
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
            AppPopup.hideLoading();
            isLoading.value = false;
            AppSnackBar.showError(
              title: 'Verification Failed',
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

  // Instant sign in helper
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        final storage = Get.find<StorageService>();
        storage.write('isLoggedIn', true);
        storage.write('userPhone', user.phoneNumber ?? phoneController.text.trim());
        Get.offAllNamed(Routes.HOME);
        AppSnackBar.showSuccess(title: 'Welcome', message: 'Logged in successfully!');
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

// Support lazy loading of StorageService inside signIn helper
class StorageServicePlaceholder {}
