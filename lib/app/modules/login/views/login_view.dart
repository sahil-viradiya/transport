import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_phone_input.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            // Right Panel: Form Card
            Expanded(
              flex: 9,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLanguageBar(context, isDark),
                        const SizedBox(height: 12),
                        _buildLoginForm(context, isDark),
                        const SizedBox(height: 24),
                        _buildUtilityRow(),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildLanguageBar(context, isDark),
                  const SizedBox(height: 16),
                  _buildBrandHeader(),
                  const SizedBox(height: 28),
                  _buildLoginForm(context, isDark),
                  const SizedBox(height: 28),
                  _buildUtilityRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageBar(BuildContext context, bool isDark) {
    return Obx(() {
      final currentLocaleCode = AppConfig.currentLocale.value.languageCode;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            _langChip('English', 'en', currentLocaleCode == 'en', isDark),
            const SizedBox(width: 4),
            _langChip('हिंदी', 'hi', currentLocaleCode == 'hi', isDark),
            const SizedBox(width: 4),
            _langChip('Español', 'es', currentLocaleCode == 'es', isDark),
          ],
        ),
      );
    });
  }

  Widget _langChip(String label, String code, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => controller.changeLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppText(
          label,
          style: AppTextStyle.labelMedium,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : AppColors.textSecondary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.local_shipping_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppText(
          'app_title'.tr,
          style: AppTextStyle.headlineLarge,
          fontWeight: FontWeight.w800,
        ),
        const SizedBox(height: 4),
        AppText(
          'app_subtitle'.tr,
          style: AppTextStyle.bodyMedium,
          color: AppColors.textSecondary,
        ),
      ],
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
              child: const Icon(Icons.local_shipping_rounded,
                  size: 450, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
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
                        AppText('app_subtitle'.tr,
                            style: AppTextStyle.labelMedium,
                            color: Colors.white70),
                      ],
                    ),
                  ],
                ),
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
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF34D399), size: 16),
                          const SizedBox(width: 6),
                          AppText('trust_banner'.tr,
                              style: AppTextStyle.labelMedium,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AppText(
                      'Track trips, diesel & earnings — your whole transport ka hisaab, ek jagah.',
                      style: AppTextStyle.headlineLarge,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security_rounded,
                            size: 16, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        AppText('secure_encryption'.tr,
                            style: AppTextStyle.labelMedium,
                            color: Colors.white.withValues(alpha: 0.8)),
                      ],
                    ),
                    AppText('v1.0',
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

  Widget _buildLoginForm(BuildContext context, bool isDark) {
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
            AppText('verify_identity'.tr,
                style: AppTextStyle.headlineSmall, fontWeight: FontWeight.w700),
            const SizedBox(height: 4),
            AppText(
              'enter_phone'.tr,
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: 24),
            AppText('phone_number_label'.tr.toUpperCase(),
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Obx(
              () => AppPhoneInput(
                controller: controller.phoneController,
                selectedDialCode: controller.selectedCountryCode.value,
                onCountryChanged: (code) =>
                    controller.selectedCountryCode.value = code,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'send_otp'.tr,
              icon: Icons.arrow_forward_rounded,
              onPressed: controller.sendOtp,
            ),
            Obx(() {
              final isMock = controller.isMockMode.value;
              return GestureDetector(
                onTap: controller.toggleMockMode,
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMock
                        ? AppColors.tertiaryLight
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isMock ? AppColors.tertiary : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMock
                            ? Icons.science_rounded
                            : Icons.cell_tower_rounded,
                        color: isMock
                            ? AppColors.tertiaryDark
                            : const Color(0xFF047857),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              isMock ? 'mock_mode'.tr : 'live_mode'.tr,
                              style: AppTextStyle.labelMedium,
                              color: isMock
                                  ? AppColors.tertiaryDark
                                  : const Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                            ),
                            const SizedBox(height: 2),
                            AppText(
                              '${'tap_to_switch'.tr} ${isMock ? "LIVE" : "MOCK"} ${'mode'.tr}',
                              style: AppTextStyle.labelMedium,
                              color: isMock
                                  ? AppColors.tertiaryDark.withValues(alpha: 0.8)
                                  : const Color(0xFF047857),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMock
                              ? AppColors.tertiary
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AppText(
                          isMock ? 'MOCK' : 'LIVE',
                          style: AppTextStyle.labelMedium,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
