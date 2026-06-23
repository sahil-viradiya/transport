import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/app/data/services/firebase_service.dart';

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
    // Normalize phone: '+91 9999999999' becomes '+919999999999'
    phone = SessionService.normalizePhone(phone);
    try {
      final firebaseService = Get.find<FirebaseService>();
      final userData = await firebaseService.getUserData(phone);

      if (userData != null) {
        // User exists, log them in immediately
        final role = userData['role'] ?? 'owner';
        await _session.setSession(
          phone: phone,
          uid: FirebaseAuth.instance.currentUser?.uid,
          name: userData['name'],
          role: role,
          avatarUrl: userData['avatarUrl'],
        );

        if (role == 'admin') {
          Get.offAllNamed(Routes.ADMIN_HOME);
        } else {
          Get.offAllNamed(Routes.HOME);
        }
        AppSnackBar.showSuccess(title: 'Welcome Back', message: 'Successfully logged in as ${role.toUpperCase()}!');
      } else {
        // User does not exist, show role selection signup dialog
        _showRoleSelectionSignupDialog(phone);
      }
    } catch (e) {
      AppSnackBar.showError(title: 'Authentication Error', message: e.toString());
    }
  }

  void _showRoleSelectionSignupDialog(String phone) {
    String selectedRole = 'owner';
    final nameController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const AppText('Complete Profile', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Please enter your details and choose your role to sign up.', style: AppTextStyle.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const AppText('Select Role:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'owner', child: AppText('Truck Owner', style: AppTextStyle.bodyMedium)),
                DropdownMenuItem(value: 'admin', child: AppText('Admin / Fleet', style: AppTextStyle.bodyMedium)),
              ],
              onChanged: (val) {
                if (val != null) selectedRole = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const AppText('Cancel', style: AppTextStyle.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                AppSnackBar.showWarning(title: 'Validation', message: 'Please enter your name.');
                return;
              }

              Get.back(); // Close dialog
              AppPopup.showLoading(message: 'Creating profile...');

              try {
                final firebaseService = Get.find<FirebaseService>();
                const avatarUrl = '';

                final userData = {
                  'name': name,
                  'phone': phone,
                  'role': selectedRole,
                  'avatarUrl': avatarUrl,
                };

                await firebaseService.saveUser(phone, userData);

                await _session.setSession(
                  phone: phone,
                  uid: FirebaseAuth.instance.currentUser?.uid,
                  name: name,
                  role: selectedRole,
                  avatarUrl: avatarUrl,
                );

                // New truck owner: seed a starter profile + demo trips so their
                // app isn't empty on first launch (all scoped to their phone).
                if (selectedRole != 'admin') {
                  await firebaseService.seedDemoDataForOwner(phone, name: name);
                }

                AppPopup.hideLoading();

                if (selectedRole == 'admin') {
                  Get.offAllNamed(Routes.ADMIN_HOME);
                } else {
                  Get.offAllNamed(Routes.HOME);
                }
                AppSnackBar.showSuccess(title: 'Account Created', message: 'Signed up successfully as ${selectedRole.toUpperCase()}!');
              } catch (e) {
                AppPopup.hideLoading();
                AppSnackBar.showError(title: 'Error', message: e.toString());
              }
            },
            child: const AppText('Submit', style: AppTextStyle.bodyMedium, color: Colors.white),
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
