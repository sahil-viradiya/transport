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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                child: Icon(Icons.local_shipping_rounded,
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.08),
            blurRadius: 24,
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        AppText(label,
            style: AppTextStyle.labelMedium,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      ],
    );
  }
}
