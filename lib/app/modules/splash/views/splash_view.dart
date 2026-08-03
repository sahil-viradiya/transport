import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/core/theme/app_images.dart';
import 'package:transport/widgets/app_image_view.dart';
import '../controllers/splash_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.saffronGradient,
          ),
        ),
        child: Stack(
          children: [
            // Faint highway artwork
            const Positioned(
              top: -30,
              left: -30,
              child: Opacity(
                opacity: 0.10,
                child: Icon(Icons.alt_route_rounded,
                    size: 240, color: Colors.white),
              ),
            ),
            const Positioned(
              bottom: -50,
              right: -30,
              child: Opacity(
                opacity: 0.10,
                child: Icon(Icons.local_shipping_rounded,
                    size: 280, color: Colors.white),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo badge
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.charcoal.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const AppImageView(
                      imagePath: AppImages.appImage,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppText('app_title'.tr,
                      style: AppTextStyle.headlineMedium,
                      color: Colors.white,
                      fontWeight: FontWeight.w800),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText('journey_partner'.tr,
                        style: AppTextStyle.labelMedium,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 72),
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        Obx(() => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: controller.loadingProgress.value,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 5,
                              ),
                            )),
                        const SizedBox(height: 14),
                        AppText('loading_fleet'.tr,
                            style: AppTextStyle.labelMedium,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: AppText('made_in_india'.tr,
                    style: AppTextStyle.labelMedium,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
