import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/otp_verification_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_otp_field.dart';
import '../../../core/theme/app_colors.dart';

class OtpVerificationView extends GetView<OtpVerificationController> {
  const OtpVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: controller.changeMobileNumber,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              
              // Centered Shield Blue Badge
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : AppColors.primaryLight.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title Header
              const Center(
                child: AppText(
                  'Verify Your Identity',
                  style: AppTextStyle.headlineMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Descriptive phone text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppText(
                    'We\'ve sent a 4-digit code to your registered mobile number ${controller.maskedPhone}',
                    style: AppTextStyle.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // OTP Digits block
              Center(
                child: AppOtpField(
                  controller: controller.otpController,
                  length: 6,
                  onCompleted: (pin) => controller.verifyOtp(),
                ),
              ),

              const SizedBox(height: 32),

              // Button: Verify & Proceed
              AppButton(
                text: 'Verify & Proceed',
                icon: Icons.arrow_forward_rounded,
                onPressed: controller.verifyOtp,
              ),

              const SizedBox(height: 32),

              // Timer / Resend Details
              Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppText(
                        'Didn\'t receive the code? ',
                        style: AppTextStyle.bodyMedium,
                      ),
                      TextButton(
                        onPressed: controller.resendTimer.value > 0 ? null : controller.resendOtp,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: AppText(
                          controller.resendTimer.value > 0
                              ? 'Resend OTP • 00:${controller.resendTimer.value.toString().padLeft(2, '0')}s'
                              : 'Resend OTP',
                          style: AppTextStyle.labelMedium,
                          color: controller.resendTimer.value > 0 ? Colors.grey : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )),

              const SizedBox(height: 24),

              // Link: Change Phone
              Center(
                child: TextButton.icon(
                  onPressed: controller.changeMobileNumber,
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  label: const AppText(
                    'Change Mobile Number',
                    style: AppTextStyle.labelMedium,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 64),

              // Secure Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  AppText(
                    'SECURE END-TO-END ENCRYPTION',
                    style: AppTextStyle.labelMedium,
                    color: isDark ? Colors.white38 : AppColors.textHint,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: AppText(
                  'The Highway Authority Digital Safety Protocol',
                  style: AppTextStyle.labelMedium,
                  color: isDark ? Colors.white24 : AppColors.textHint.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
