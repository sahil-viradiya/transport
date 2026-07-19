import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/proof_of_delivery_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';

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
        title: const AppText('The Highway Authority',
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

            // Take Photo (Camera Box Card)
            GestureDetector(
              onTap: controller.takePhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const AppText('Take Photo',
                        style: AppTextStyle.bodyLarge,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    const SizedBox(height: 4),
                    const AppText('Use Camera',
                        style: AppTextStyle.labelMedium, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reactive Preview Card (Dotted Border container)
            Obx(() {
              final bytes = controller.pickedBytes.value;
              if (bytes == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            AppText('Document Preview',
                                style: AppTextStyle.bodyLarge,
                                fontWeight: FontWeight.bold),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFE380).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const AppText('Draft',
                              style: AppTextStyle.labelMedium,
                              color: Color(0xFFBF2600),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Scanned Document image illustration container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: Stack(
                          children: [
                            // Render the picked image bytes (web + mobile safe)
                            Image.memory(bytes,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover),

                            // Bottom Info Overlay Bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppText(
                                            'proof_of_delivery.jpg',
                                            style: AppTextStyle.bodyMedium,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          AppText(
                                            'Uploaded today, 14:22 PM',
                                            style: AppTextStyle.labelMedium,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: controller.deletePhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
