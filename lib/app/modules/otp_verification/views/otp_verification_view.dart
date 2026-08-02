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
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Panel: Web Brand Hero
            Expanded(
              flex: 11,
              child: _buildWebBrandBanner(),
            ),
            // Right Panel: OTP Form Card
            Expanded(
              flex: 9,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _buildOtpCard(context, isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Layout
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: controller.changeMobileNumber,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildOtpFormContent(context, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebBrandBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF042F20),
            Color(0xFF065F46),
            Color(0xFF047857),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -60,
            bottom: -40,
            child: Opacity(
              opacity: 0.08,
              child:
                  Icon(Icons.shield_outlined, size: 450, color: Colors.white),
            ),
          ),
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Color(0xFF059669), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('app_title'.tr,
                            style: AppTextStyle.headlineSmall,
                            color: Colors.white,
                            fontWeight: FontWeight.w800),
                        AppText('security_portal'.tr,
                            style: AppTextStyle.labelMedium,
                            color: Colors.white70),
                      ],
                    ),
                  ],
                ),

                // Center Copy & Highlights
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              color: Color(0xFF34D399), size: 16),
                          SizedBox(width: 6),
                          AppText('two_factor_authentication'.tr,
                              style: AppTextStyle.labelMedium,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppText(
                      'fleet_security_heading'.tr,
                      style: AppTextStyle.headlineLarge,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'otp_security_description'.tr,
                      style: AppTextStyle.bodyLarge,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: _webFeatureCard(
                            Icons.phonelink_ring_rounded,
                            'instant_sms_delivery'.tr,
                            'fast_otp_generation'.tr,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _webFeatureCard(
                            Icons.verified_user_rounded,
                            'end_to_end_encryption'.tr,
                            'secure_session_keys'.tr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom Footer Note
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security_rounded,
                            size: 16, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        AppText('highway_safety_protocol'.tr,
                            style: AppTextStyle.labelMedium,
                            color: Colors.white.withValues(alpha: 0.8)),
                      ],
                    ),
                    AppText('made_in_india'.tr,
                        style: AppTextStyle.labelMedium,
                        color: Colors.white.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _webFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF34D399), size: 24),
          const SizedBox(height: 10),
          AppText(title,
              style: AppTextStyle.bodyMedium,
              color: Colors.white,
              fontWeight: FontWeight.bold),
          const SizedBox(height: 2),
          AppText(subtitle,
              style: AppTextStyle.labelMedium, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildOtpCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: controller.changeMobileNumber,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'change_phone_number'.tr,
              ),
              const SizedBox(width: 8),
              AppText('security_verification'.tr,
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          _buildOtpFormContent(context, isDark),
        ],
      ),
    );
  }

  Widget _buildOtpFormContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centered Shield Blue Badge
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : AppColors.primaryLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 40,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Title Header
        Center(
          child: AppText(
            'verify_identity'.tr,
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
              'We\'ve sent a 6-digit code to your registered mobile number ${controller.maskedPhone}',
              style: AppTextStyle.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: 36),

        // OTP Digits block
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppOtpField(
              controller: controller.otpController,
              length: 6,
              onCompleted: (pin) => controller.verifyOtp(),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Button: Verify & Proceed
        AppButton(
          text: 'Verify & Proceed',
          icon: Icons.arrow_forward_rounded,
          onPressed: controller.verifyOtp,
        ),

        const SizedBox(height: 24),

        // Timer / Resend Details
        Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppText(
                  'Didn\'t receive the code? ',
                  style: AppTextStyle.bodyMedium,
                ),
                TextButton(
                  onPressed: controller.resendTimer.value > 0
                      ? null
                      : controller.resendOtp,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: AppText(
                    controller.resendTimer.value > 0
                        ? 'Resend OTP • 00:${controller.resendTimer.value.toString().padLeft(2, '0')}s'
                        : 'Resend OTP',
                    style: AppTextStyle.labelMedium,
                    color: controller.resendTimer.value > 0
                        ? Colors.grey
                        : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )),

        const SizedBox(height: 16),

        // Link: Change Phone
        Center(
          child: TextButton.icon(
            onPressed: controller.changeMobileNumber,
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.primary),
            label: const AppText(
              'Change Mobile Number',
              style: AppTextStyle.labelMedium,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 32),

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
            color: isDark
                ? Colors.white24
                : AppColors.textHint.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
