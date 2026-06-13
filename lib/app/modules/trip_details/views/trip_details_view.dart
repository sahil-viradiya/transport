import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_image_view.dart';
import '../../../core/theme/app_colors.dart';

class TripDetailsView extends GetView<TripDetailsController> {
  const TripDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const AppText('Trip Details', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.red),
            onPressed: controller.triggerEmergencySos,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Assignment info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('CURRENT ASSIGNMENT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                    const SizedBox(height: 6),
                    AppText(controller.tripId, style: AppTextStyle.headlineLarge, fontWeight: FontWeight.w900),
                    const SizedBox(height: 12),
                    
                    // Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const AppText('In Transit', style: AppTextStyle.labelMedium, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const AppText('Priority Delivery', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    
                    const Divider(height: 24),
                    
                    // Document buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                            label: const AppText('Expense Logs', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                            label: const AppText('Proof', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Route Map illustration card
            Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  const AppImageView(
                    // Custom logistics map screenshot
                    imagePath: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600&auto=format&fit=crop',
                    borderRadius: 16,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ),
                  
                  // Start/End points graphic highlights
                  const Positioned(
                    top: 40,
                    left: 60,
                    child: Icon(Icons.radio_button_checked_rounded, color: Colors.greenAccent, size: 28),
                  ),
                  const Positioned(
                    bottom: 60,
                    right: 80,
                    child: Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 32),
                  ),
                  
                  // Floating overlays
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('REMAINING DISTANCE', style: AppTextStyle.labelMedium, color: AppColors.textHint, fontWeight: FontWeight.bold),
                          Obx(() => AppText(
                                controller.remainingDistance.value,
                                style: AppTextStyle.bodyLarge,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pickup & drop timeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Pickup Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.upload_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('PICKUP ADDRESS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                              const SizedBox(height: 4),
                              AppText(controller.pickupAddress, style: AppTextStyle.bodyMedium),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  AppText('Contact: ${controller.pickupContact}', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Line connector
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(width: 2, height: 28, color: AppColors.border),
                      ),
                    ),

                    // Drop Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.download_rounded, color: Colors.orange, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('DROP-OFF ADDRESS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                              const SizedBox(height: 4),
                              AppText(controller.dropoffAddress, style: AppTextStyle.bodyMedium),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  AppText('Contact: ${controller.dropoffContact}', style: AppTextStyle.labelMedium, color: Colors.orange, fontWeight: FontWeight.bold),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Material particulars
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSpecificationTile(
                      icon: Icons.widgets_outlined,
                      title: 'MATERIAL TYPE',
                      value: controller.materialType,
                      subtitle: controller.materialSubtitle,
                      color: Colors.blue,
                    ),
                    const Divider(height: 24),
                    _buildSpecificationTile(
                      icon: Icons.scale_outlined,
                      title: 'LOAD WEIGHT',
                      value: controller.loadWeight,
                      subtitle: 'Axle Limit Confirmed',
                      color: Colors.brown,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer block
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFDEEBFF).withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                    child: const Center(
                      child: AppText('RK', style: AppTextStyle.labelLarge, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('CUSTOMER', style: AppTextStyle.labelMedium),
                      AppText('Rajesh Kumar', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                      AppText('Platinum Corporate Client', style: AppTextStyle.labelMedium),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Trip Status Timelines
            const AppText('Trip Status', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() => ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.milestones.length,
                      itemBuilder: (context, index) {
                        final node = controller.milestones[index];
                        final isLast = index == controller.milestones.length - 1;
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Milestone node indicators
                            Column(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: node.isCompleted ? AppColors.primary : Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: node.isCompleted
                                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                                      : const SizedBox.shrink(),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: node.isCompleted ? AppColors.primary : Colors.grey.shade200,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            
                            // Text details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    node.title,
                                    style: AppTextStyle.bodyLarge,
                                    fontWeight: node.isCompleted ? FontWeight.bold : FontWeight.normal,
                                    color: node.isCompleted ? AppColors.textPrimary : AppColors.textHint,
                                  ),
                                  if (node.description != null) ...[
                                    const SizedBox(height: 2),
                                    AppText(node.description!, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                                  ],
                                  const SizedBox(height: 2),
                                  AppText(node.time, style: AppTextStyle.labelMedium, color: AppColors.textHint),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )),
              ),
            ),

            const SizedBox(height: 24),

            // Estimations banner (Blue gradient box)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppText(
                    'ESTIMATED TIME',
                    style: AppTextStyle.labelMedium,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 6),
                  Obx(() => AppText(
                        controller.estimatedTime.value,
                        style: AppTextStyle.headlineLarge,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Obx(() => AppText(
                        'Fuel consumed so far: ${controller.fuelConsumed.value}L',
                        style: AppTextStyle.labelMedium,
                        color: Colors.white70,
                      )),
                  const SizedBox(height: 20),
                  AppButton(
                    text: 'Update Status',
                    icon: Icons.arrow_forward_rounded,
                    type: AppButtonType.outlined,
                    onPressed: controller.updateStatus,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, style: AppTextStyle.labelMedium),
              const SizedBox(height: 2),
              AppText(value, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
              AppText(subtitle, style: AppTextStyle.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}
