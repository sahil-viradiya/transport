import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_text_field.dart';
import '../../../core/theme/app_colors.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Panel: Web Brand Hero
            Expanded(
              flex: 11,
              child: _buildWebBrandBanner(),
            ),
            // Right Panel: Form Card
            Expanded(
              flex: 9,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLoginCard(context),
                        const SizedBox(height: 24),
                        _buildUtilityRow(),
                        const SizedBox(height: 28),
                        const AppText(
                          'The Highway Authority  •  v1.0',
                          style: AppTextStyle.labelMedium,
                          textAlign: TextAlign.center,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 4),
                        const AppText(
                          'Made in India for Bharat\'s truck owners 🚚',
                          style: AppTextStyle.labelMedium,
                          textAlign: TextAlign.center,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
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
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildLoginCard(context),
                        const SizedBox(height: 20),
                        _buildUtilityRow(),
                        const SizedBox(height: 24),
                        const AppText(
                          'The Highway Authority  •  v1.0',
                          style: AppTextStyle.labelMedium,
                          textAlign: TextAlign.center,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 4),
                        const AppText(
                          'Made in India for Bharat\'s truck owners 🚚',
                          style: AppTextStyle.labelMedium,
                          textAlign: TextAlign.center,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
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
          Positioned(
            right: -60,
            bottom: -40,
            child: Opacity(
              opacity: 0.08,
              child: const Icon(Icons.local_shipping_rounded, size: 450, color: Colors.white),
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
                      child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF059669), size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('The Highway Authority', style: AppTextStyle.headlineSmall, color: Colors.white, fontWeight: FontWeight.w800),
                        AppText('Logistics & Fleet OS • Bharat Edition', style: AppTextStyle.labelMedium, color: Colors.white70),
                      ],
                    ),
                  ],
                ),

                // Center Highlight Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 16),
                          SizedBox(width: 6),
                          AppText('Bharat\'s Most Trusted Transport Platform', style: AppTextStyle.labelMedium, color: Colors.white, fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AppText(
                      'Smart Transport & Trip Management,\nAll in One Place.',
                      style: AppTextStyle.headlineLarge,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'Track active trips, driver locations, diesel expenses & POD proofs with real-time sync across web and mobile.',
                      style: AppTextStyle.bodyLarge,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    const SizedBox(height: 36),

                    // Feature Pill Highlights
                    Row(
                      children: [
                        Expanded(
                          child: _webFeatureCard(
                            Icons.location_on_rounded,
                            'Live GPS Tracking',
                            'Real-time trip updates',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _webFeatureCard(
                            Icons.receipt_long_rounded,
                            'Digital POD & Expenses',
                            'Instant trip auditing',
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
                        const Icon(Icons.security_rounded, size: 16, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        AppText('256-bit Encrypted Safety', style: AppTextStyle.labelMedium, color: Colors.white.withValues(alpha: 0.8)),
                      ],
                    ),
                    AppText('Made in India 🇮🇳  •  v1.0', style: AppTextStyle.labelMedium, color: Colors.white.withValues(alpha: 0.6)),
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
          AppText(title, style: AppTextStyle.bodyMedium, color: Colors.white, fontWeight: FontWeight.bold),
          const SizedBox(height: 2),
          AppText(subtitle, style: AppTextStyle.labelMedium, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.saffronGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -20,
              child: Opacity(
                opacity: 0.14,
                child: const Icon(Icons.local_shipping_rounded,
                    size: 200, color: Colors.white),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              AppText('English',
                                  style: AppTextStyle.labelMedium,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const AppText('The Highway\nAuthority',
                        style: AppTextStyle.headlineLarge,
                        color: Colors.white,
                        fontWeight: FontWeight.w800),
                    const SizedBox(height: 8),
                    AppText(
                      'Track trips, diesel & earnings — your whole transport ka hisaab, ek jagah.',
                      style: AppTextStyle.bodyMedium,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Welcome 👋',
                style: AppTextStyle.headlineSmall, fontWeight: FontWeight.w700),
            const SizedBox(height: 4),
            const AppText(
              'Apne mobile number se login karein. OTP bhejenge.',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: 24),
            const AppText('MOBILE NUMBER',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary),
            const SizedBox(height: 8),
            AppTextField(
              controller: controller.phoneController,
              hintText: '98765 43210',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              prefixText: '+91  ',
              validator: (val) {
                final digits = (val ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) {
                  return 'Phone number is required';
                }
                if (digits.length != 10) {
                  return 'Sahi 10 digit mobile number daalein';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Send OTP',
              icon: Icons.arrow_forward_rounded,
              onPressed: controller.sendOtp,
            ),
            Obx(() => controller.isMockMode.value
                ? Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.tertiary),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded,
                            color: AppColors.tertiaryDark, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            'Test mode: OTP code "123456" daalein.',
                            style: AppTextStyle.labelMedium,
                            color: AppColors.tertiaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _utility(Icons.headset_mic_rounded, '24/7 Help', AppColors.info),
        _utility(Icons.verified_user_rounded, 'Secure', AppColors.success),
        _utility(Icons.sos_rounded, 'SOS', AppColors.error),
      ],
    );
  }

  Widget _utility(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        AppText(
          label,
          style: AppTextStyle.labelMedium,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ],
    );
  }
}
