import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_text_field.dart';
import '../../../../widgets/app_image_view.dart';
import '../../../core/theme/app_colors.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AppText(
                          'THA',
                          style: AppTextStyle.headlineSmall,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1.5,
                          height: 24,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText('The Highway', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                            AppText('Authority', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                          ],
                        ),
                      ],
                    ),
                    // Language Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          AppText('English', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Hero Truck graphic card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 180,
                child: Stack(
                  children: [
                    const AppImageView(
                      imagePath: 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=600&auto=format&fit=crop',
                      borderRadius: 16,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Your Digital Co-Pilot\nfor the Road.',
                            style: AppTextStyle.headlineSmall,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          SizedBox(height: 6),
                          AppText(
                            'Track trips, manage fuel, and stay connected with India\'s largest logistics network.',
                            style: AppTextStyle.labelMedium,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mock mode indicator banner
              Obx(() => controller.isMockMode.value
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.tertiary),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.tertiaryDark, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: AppText(
                              'Firebase Mock Mode Active. Send OTP and verify with code "1234".',
                              style: AppTextStyle.labelMedium,
                              color: AppColors.tertiaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink()),

              const SizedBox(height: 16),

              // Driver login card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppText('Driver Login', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
                        const SizedBox(height: 4),
                        const AppText(
                          'Please enter your credentials to continue your journey.',
                          style: AppTextStyle.bodyMedium,
                        ),
                        const SizedBox(height: 20),

                        // Login Method Tabs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.password_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                                      const SizedBox(width: 6),
                                      AppText(
                                        'Password',
                                        style: AppTextStyle.labelMedium,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sms_rounded, size: 18, color: AppColors.primary),
                                      SizedBox(width: 6),
                                      AppText(
                                        'OTP',
                                        style: AppTextStyle.labelMedium,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Phone Entry form details
                        _buildPhoneRequestFlow(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Extra features row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomUtility(Icons.headset_mic_outlined, '24/7 Help', Colors.orange),
                  _buildBottomUtility(Icons.security_outlined, 'Secure', Colors.blue),
                  _buildBottomUtility(Icons.star_outline_rounded, 'SOS', Colors.red),
                ],
              ),

              const SizedBox(height: 32),

              // Version details
              const Center(
                child: AppText(
                  'The Highway Authority v4.2.0 • Build 9012',
                  style: AppTextStyle.labelMedium,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AppText(
                  '© 2024 The Highway Authority. For official use by authorized drivers only.',
                  style: AppTextStyle.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile number input step
  Widget _buildPhoneRequestFlow() {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText(
            'MOBILE NUMBER',
            style: AppTextStyle.labelMedium,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller.phoneController,
            hintText: 'e.g. +91 9876543210',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_android_outlined,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Phone number is required';
              }
              if (!val.startsWith('+')) {
                return 'Please include country code (e.g. +91)';
              }
              if (val.length < 10) {
                return 'Enter a valid mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Send Verification Code',
            icon: Icons.arrow_forward_rounded,
            onPressed: controller.sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomUtility(IconData icon, String label, Color color) {
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        AppText(
          label,
          style: AppTextStyle.labelMedium,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : AppColors.secondary,
        ),
      ],
    );
  }
}
