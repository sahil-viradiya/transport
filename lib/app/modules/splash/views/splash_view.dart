import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/splash_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Background Path artwork (Top Left)
          Positioned(
            top: -40,
            left: -20,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.04,
              child: Icon(
                Icons.alt_route_rounded,
                size: 240,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Background Pin artwork (Bottom Right)
          Positioned(
            bottom: -50,
            right: -30,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.04,
              child: Icon(
                Icons.location_on_rounded,
                size: 260,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Center Logo and content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stylized Rounded Box containing Truck Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Brand Titles
                const AppText(
                  'The Highway Authority',
                  style: AppTextStyle.headlineMedium,
                  fontWeight: FontWeight.w900,
                ),
                const SizedBox(height: 6),
                AppText(
                  'THE DIGITAL CO-PILOT',
                  style: AppTextStyle.labelMedium,
                  color: isDark ? Colors.white54 : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
                
                const SizedBox(height: 80),
                
                // Progress Loader
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Column(
                    children: [
                      Obx(() => LinearProgressIndicator(
                            value: controller.loadingProgress.value,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          )),
                      const SizedBox(height: 16),
                      AppText(
                        'INITIALIZING CARGO SYSTEMS...',
                        style: AppTextStyle.labelMedium,
                        color: isDark ? Colors.white38 : AppColors.textHint,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
