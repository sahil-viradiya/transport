import 'dart:io';
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

    return Obx(() {
      if (!controller.isJourneyStarted.value) {
        return _buildStartConfirmationView(context, isDark);
      } else {
        return _buildActiveTrackingView(context, isDark);
      }
    });
  }

  // SCREEN 1: Trip Start Confirmation (Confirm Journey)
  Widget _buildStartConfirmationView(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const AppText('Confirm Journey',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const AppText(
                  'GPS ACTIVE',
                  style: AppTextStyle.labelMedium,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Map Illustration Card
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  const AppImageView(
                    imagePath:
                        'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600&auto=format&fit=crop',
                    borderRadius: 16,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ),

                  // Route path mock icons
                  const Positioned(
                    top: 30,
                    left: 70,
                    child: Icon(Icons.radio_button_checked_rounded,
                        color: Colors.greenAccent, size: 24),
                  ),
                  const Positioned(
                    bottom: 40,
                    right: 80,
                    child: Icon(Icons.location_on_rounded,
                        color: Colors.redAccent, size: 28),
                  ),

                  // Bottom Pill Overlays
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Obx(() => _buildMapOverlayPill(Icons.route_outlined,
                            controller.remainingDistance.value)),
                        const SizedBox(width: 8),
                        Obx(() => _buildMapOverlayPill(
                            Icons.access_time_rounded,
                            controller.estimatedTime.value)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Departure Card
            _buildDetailCard(
              isDark: isDark,
              label: 'DEPARTURE',
              title: controller.departureTitle,
              subtitle: controller.departureSubtitle,
              footerIcon: Icons.calendar_today_rounded,
              footerText: controller.departureTime,
            ),
            const SizedBox(height: 12),

            // 3. Destination Card
            _buildDetailCard(
              isDark: isDark,
              label: 'DESTINATION',
              title: controller.destinationTitle,
              subtitle: controller.destinationSubtitle,
              footerIcon: Icons.local_shipping_rounded,
              footerText: 'Consignment ${controller.consignmentNo}',
            ),
            const SizedBox(height: 12),

            // 4. Manifest Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE9F2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText('MANIFEST DETAILS',
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold),
                          const SizedBox(height: 4),
                          AppText(controller.manifestTitle,
                              style: AppTextStyle.bodyLarge,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7A5900), // Brown bg
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const AppText(
                          'HIGH VALUE',
                          style: AppTextStyle.labelMedium,
                          color: Color(0xFFFFE380), // Gold text
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildManifestGridItem('WEIGHT', controller.weight),
                      _buildManifestGridItem('UNITS', controller.units),
                      _buildManifestGridItem('VEHICLE', controller.vehicleNo),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Final Checks
            const AppText('Final Checks',
                style: AppTextStyle.labelLarge, fontWeight: FontWeight.bold),
            const SizedBox(height: 10),
            _buildChecklistItem(isDark, 'Vehicle Inspection Completed'),
            const SizedBox(height: 8),
            _buildChecklistItem(isDark, 'Load weight certified and secured'),
            const SizedBox(height: 8),
            _buildChecklistItem(isDark, 'Driver declarations accepted'),

            const SizedBox(height: 32),

            // 6. Action Button: Start Journey
            AppButton(
              text: 'Start Journey',
              icon: Icons.play_arrow_rounded,
              onPressed: controller.startJourney,
            ),
            const SizedBox(height: 12),
            Center(
              child: AppText(
                'By starting, you confirm you are fit for duty and will comply with all national highway safety regulations.',
                style: AppTextStyle.labelMedium,
                color: isDark ? Colors.white30 : AppColors.textHint,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // SCREEN 2: Active Trip Tracking
  Widget _buildActiveTrackingView(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFF09202F), // Slate contours gradient base
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const AppText('The Highway Authority',
            style: AppTextStyle.headlineSmall,
            color: Colors.white,
            fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2838), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A. Top Indicators Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left status and sync stack
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const AppText('GPS Live Sync',
                                  style: AppTextStyle.labelMedium,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Obx(() => AppText(
                                'Last synced: ${controller.lastSynced.value}',
                                style: AppTextStyle.labelMedium,
                                color: Colors.white70,
                              )),
                        ),
                        const SizedBox(height: 8),
                        Obx(() => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Colors.redAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: AppText(
                                      controller.currentAddress.value,
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.white70,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right circular Speed Gauge
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.speed_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(height: 2),
                          Obx(() => AppText(
                                '${controller.speed.value}',
                                style: AppTextStyle.headlineSmall,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              )),
                          const AppText('KM/H',
                              style: AppTextStyle.labelMedium,
                              color: Colors.white54,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // B. Active Trip Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(controller.vehicleNo,
                                  style: AppTextStyle.bodyLarge,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold),
                              AppText(
                                  'Route: ${controller.departureTitle} ➔ ${controller.destinationTitle}',
                                  style: AppTextStyle.labelMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('NEXT STOP ETA',
                                  style: AppTextStyle.labelMedium),
                              const SizedBox(height: 2),
                              Obx(() => AppText(
                                    controller.estimatedTime.value,
                                    style: AppTextStyle.headlineLarge,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const AppText('REMAINING',
                                  style: AppTextStyle.labelMedium),
                              const SizedBox(height: 2),
                              Obx(() => AppText(
                                    controller.remainingDistance.value,
                                    style: AppTextStyle.headlineLarge,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thick Journey Progress Bar
                    Obx(() {
                      // Mock progress value based on current milestone state
                      double progressVal = 0.35;
                      if (controller.currentMilestone.value == 2)
                        progressVal = 0.65;
                      if (controller.currentMilestone.value > 2)
                        progressVal = 1.0;

                      return LinearProgressIndicator(
                        value: progressVal,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                            '${controller.departureTitle.split(' ').first} (Started)',
                            style: AppTextStyle.labelMedium),
                        AppText(
                            '${controller.destinationTitle.split(' ').first} (Destination)',
                            style: AppTextStyle.labelMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // C. Milestone Action Cards (Reached Pickup, Loaded, Reached Drop)
              _buildMilestoneActionCard(
                index: 1,
                icon: Icons.location_on_outlined,
                label: 'Reached Pickup',
              ),
              const SizedBox(height: 12),
              _buildMilestoneActionCard(
                index: 2,
                icon: Icons.inventory_2_outlined,
                label: 'Loaded',
              ),
              const SizedBox(height: 12),
              _buildMilestoneActionCard(
                index: 3,
                icon: Icons.check_circle_outline_rounded,
                label: 'Reached Drop',
              ),
              _buildPODDetailsCard(context, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPODDetailsCard(BuildContext context, bool isDark) {
    return Obx(() {
      final hasPod = controller.currentMilestone.value == 4;
      if (!hasPod) return const SizedBox.shrink();

      final imgPath = controller.podUrl.value;
      final remarksText = controller.remarks.value;

      ImageProvider? imgProvider;
      if (imgPath.isNotEmpty) {
        if (imgPath.startsWith('http://') || imgPath.startsWith('https://')) {
          imgProvider = NetworkImage(imgPath);
        } else {
          final file = File(imgPath);
          if (file.existsSync()) {
            imgProvider = FileImage(file);
          } else {
            imgProvider = const NetworkImage('https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600');
          }
        }
      }

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                const AppText(
                  'PROOF OF DELIVERY SUBMITTED',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ],
            ),
            const Divider(height: 24),
            if (remarksText.isNotEmpty) ...[
              const AppText(
                'REMARKS / NOTES',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 6),
              AppText(
                remarksText,
                style: AppTextStyle.bodyMedium,
                color: isDark ? Colors.white70 : AppColors.secondary,
              ),
              const SizedBox(height: 16),
            ],
            if (imgProvider != null) ...[
              const AppText(
                'DELIVERY RECEIPT PHOTO',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image(
                    image: imgProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // Common UI building helpers for Confirm Journey
  Widget _buildMapOverlayPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 4),
          AppText(text,
              style: AppTextStyle.labelMedium,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required bool isDark,
    required String label,
    required String title,
    required String subtitle,
    required IconData footerIcon,
    required String footerText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label,
              style: AppTextStyle.labelMedium,
              color: isDark ? Colors.white30 : AppColors.textHint,
              fontWeight: FontWeight.bold),
          const SizedBox(height: 6),
          AppText(title,
              style: AppTextStyle.bodyLarge,
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold),
          const SizedBox(height: 2),
          AppText(subtitle, style: AppTextStyle.labelMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(footerIcon, color: AppColors.primary, size: 14),
              const SizedBox(width: 6),
              AppText(footerText,
                  style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManifestGridItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, style: AppTextStyle.labelMedium),
          const SizedBox(height: 2),
          AppText(value,
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryDark),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: Color(0xFFE3FCEF), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Color(0xFF006644), size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: AppText(text,
                  style: AppTextStyle.bodyMedium,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Interactive milestone cards for Active Trip Tracking view
  Widget _buildMilestoneActionCard({
    required int index,
    required IconData icon,
    required String label,
  }) {
    return Obx(() {
      final dbMilestone = controller.currentMilestone.value;
      final activeMilestone = dbMilestone == 0 ? 1 : dbMilestone;
      final isCompleted = index < activeMilestone;
      final isActive = index == activeMilestone;

      // Solid blue style if active (needs action)
      if (isActive) {
        return GestureDetector(
          onTap: () => controller.selectMilestone(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                AppText(label,
                    style: AppTextStyle.bodyLarge,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ],
            ),
          ),
        );
      }

      // Completed check state styling (white card, green/grey check)
      if (isCompleted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 22),
              const SizedBox(width: 10),
              AppText(label,
                  style: AppTextStyle.bodyLarge,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
            ],
          ),
        );
      }

      // Locked/disabled state (unreached milestone yet)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 22),
            const SizedBox(width: 10),
            AppText(label,
                style: AppTextStyle.bodyLarge, color: Colors.grey.shade400),
          ],
        ),
      );
    });
  }
}
