import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/proof_of_delivery_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/proof_of_delivery_preview.dart';

class ProofOfDeliveryView extends GetView<ProofOfDeliveryController> {
  const ProofOfDeliveryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: AppText('app_title'.tr,
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trip ID tag
            Obx(() => AppText(
                  'TRIP ID: #${controller.tripId.value.toUpperCase()}',
                  style: AppTextStyle.labelMedium,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 6),
            const AppText(
              'Proof of Delivery',
              style: AppTextStyle.headlineMedium,
              fontWeight: FontWeight.w900,
            ),
            const SizedBox(height: 6),
            AppText(
              'Upload a clear photo of the signed receipt or consignment note to complete this trip.',
              style: AppTextStyle.bodyMedium,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
            const SizedBox(height: 24),

            // Single Premium Camera Upload Card (Only Camera allowed for Proof of Delivery)
            GestureDetector(
              onTap: controller.takePhoto,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Take POD Photo 📸',
                            style: AppTextStyle.titleLarge,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          SizedBox(height: 4),
                          AppText(
                            'Tap to open camera & capture receipt',
                            style: AppTextStyle.labelMedium,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reactive Preview Card (Dotted Border container)
            Obx(() {
              final bytes = controller.pickedBytes.value;
              if (bytes == null) return const SizedBox.shrink();

              return ProofOfDeliveryPreview(
                bytes: bytes,
                isDark: isDark,
                onDelete: controller.deletePhoto,
              );
            }),

            // Remarks Area
            const AppText('REMARKS / NOTES',
                style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE9F2FF).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: controller.remarksController,
                maxLines: 3,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Enter any discrepancies, damage notes, or recipient name...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : AppColors.textHint,
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button & Progress Indicators
            Obx(() {
              if (controller.isUploading.value) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sync_rounded,
                                  color: AppColors.primary, size: 16),
                              SizedBox(width: 8),
                              AppText('Uploading Proof...',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold),
                            ],
                          ),
                          AppText(
                              '${(controller.uploadProgress.value * 100).toInt()}%',
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: controller.uploadProgress.value,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ],
                  ),
                );
              }

              return AppButton(
                text: 'Submit Proof',
                icon: Icons.cloud_upload_rounded,
                onPressed: controller.submitProof,
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Draw a beautiful mock receipt vector graphic using container lines
}
