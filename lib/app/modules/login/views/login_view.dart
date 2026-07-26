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
                        _buildUtilityRow(isDark),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF081E13), // dark deep green-forest
                    const Color(0xFF0F172A), // slate 900
                    const Color(0xFF0A0F1D), // very dark navy
                  ]
                : [
                    const Color(0xFFE8F5E9), // soft pastel green
                    const Color(0xFFF8FAFC), // slate 50
                    const Color(0xFFEEF2F6), // soft slate grey
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Ambient Decorative glow circles
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark
                            ? const Color(0xFF059669)
                            : const Color(0xFF81C784))
                        .withOpacity(isDark ? 0.08 : 0.2),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF90CAF9))
                        .withOpacity(isDark ? 0.06 : 0.15),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _buildLanguageBar(context, isDark),
                        ),
                        const SizedBox(height: 24),
                        _buildBrandHeader(isDark),
                        const SizedBox(height: 28),
                        _buildLoginForm(context, isDark),
                        const SizedBox(height: 32),
                        _buildUtilityRow(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            const Icon(Icons.language_rounded,
                size: 16, color: AppColors.primary),
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

  Widget _buildBrandHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                      .withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                        .withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.local_shipping_rounded,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppText(
          'app_title'.tr,
          style: AppTextStyle.headlineLarge,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          textAlign: TextAlign.center,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        const SizedBox(height: 6),
        AppText(
          'app_subtitle'.tr,
          style: AppTextStyle.bodyMedium,
          textAlign: TextAlign.center,
          color: isDark ? Colors.white54 : const Color(0xFF475569),
          fontWeight: FontWeight.w600,
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
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AppText(
          //   'verify_identity'.tr,
          //   style: AppTextStyle.headlineSmall,
          //   fontWeight: FontWeight.w800,
          //   color: isDark ? Colors.white : const Color(0xFF0F172A),
          // ),
          // const SizedBox(height: 6),
          AppText(
            'enter_phone'.tr,
            style: AppTextStyle.bodyMedium,
            color: isDark ? Colors.white60 : const Color(0xFF475569),
          ),
          const SizedBox(height: 6),
          Obx(
            () => AppPhoneInput(
              controller: controller.phoneController,
              selectedDialCode: controller.selectedCountryCode.value,
              onCountryChanged: (code) =>
                  controller.selectedCountryCode.value = code,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AppButton(
              text: 'send_otp'.tr,
              icon: Icons.arrow_forward_rounded,
              onPressed: controller.sendOtp,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() {
            final isMock = controller.isMockMode.value;
            return GestureDetector(
              onTap: controller.toggleMockMode,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isMock
                      ? (isDark
                          ? const Color(0xFF3B2001)
                          : const Color(0xFFFEF3C7))
                      : (isDark
                          ? const Color(0xFF06331E)
                          : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMock
                        ? (isDark
                            ? const Color(0xFFD97706).withOpacity(0.4)
                            : const Color(0xFFFCD34D))
                        : (isDark
                            ? const Color(0xFF10B981).withOpacity(0.4)
                            : const Color(0xFFA7F3D0)),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMock
                            ? (isDark
                                ? const Color(0xFF78350F)
                                : const Color(0xFFFFFBEB))
                            : (isDark
                                ? const Color(0xFF064E3B)
                                : const Color(0xFFF0FDF4)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isMock
                            ? Icons.science_rounded
                            : Icons.cell_tower_rounded,
                        color: isMock
                            ? const Color(0xFFD97706)
                            : const Color(0xFF10B981),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText(
                            isMock ? 'mock_mode'.tr : 'live_mode'.tr,
                            style: AppTextStyle.labelMedium,
                            color: isMock
                                ? (isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF92400E))
                                : (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF065F46)),
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            '${'tap_to_switch'.tr} ${isMock ? "LIVE" : "MOCK"} ${'mode'.tr}',
                            style: AppTextStyle.labelMedium,
                            fontSize: 11,
                            color: isMock
                                ? (isDark
                                    ? const Color(0xFFFBBF24).withOpacity(0.7)
                                    : const Color(0xFFB45309))
                                : (isDark
                                    ? const Color(0xFF34D399).withOpacity(0.7)
                                    : const Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMock
                            ? const Color(0xFFD97706)
                            : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(
                        isMock ? 'MOCK' : 'LIVE',
                        style: AppTextStyle.labelMedium,
                        fontSize: 10,
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
    );
  }

  Widget _buildUtilityRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _utility(
            Icons.headset_mic_rounded, '24/7 Help', AppColors.info, isDark),
        _utility(
            Icons.verified_user_rounded, 'Secure', AppColors.success, isDark),
        _utility(Icons.sos_rounded, 'SOS', AppColors.error, isDark),
      ],
    );
  }

  Widget _utility(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          AppText(
            label,
            style: AppTextStyle.labelMedium,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: isDark
                ? Colors.white.withOpacity(0.8)
                : const Color(0xFF334155),
          ),
        ],
      ),
    );
  }
}
