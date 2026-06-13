import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import '../controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      } else {
        return const NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pull parent HomeController to switch tabs
    final homeController = Get.find<HomeController>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const AppText('The Highway Authority',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.red),
            onPressed: controller.triggerEmergencySos,
          ),
        ],
      ),
      body: Obx(() {
        if (!controller.isOnline.value) {
          return _buildOfflineView(context, isDark);
        }

        return RefreshIndicator(
          onRefresh: controller.loadProfileFromFirebase,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Profile block
            Row(
              children: [
                Obx(() => Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    image: DecorationImage(
                      image: _getImageProvider(controller.avatarUrl.value),
                      fit: BoxFit.cover,
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('Welcome back,',
                          style: AppTextStyle.bodyMedium),
                      Obx(() => AppText(
                            controller.driverName.value,
                            style: AppTextStyle.bodyLarge,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
                // Active status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.green, size: 10),
                      SizedBox(width: 4),
                      AppText('ACTIVE DUTY',
                          style: AppTextStyle.labelMedium,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Today's Truck & Trips summary cards
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(
                  title: 'ASSIGNED TRUCK',
                  value: () => controller.vehicleNo.value,
                  icon: Icons.local_shipping_rounded,
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'TODAY\'S TRIPS',
                  value: () => controller.todayTripsCount.value
                      .toString()
                      .padLeft(2, '0'),
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.tertiaryDark,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Active Trip Blue Gradient Box
            Obx(() {
              final activeTrip = controller.activeTrip;
              
              if (activeTrip == null) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: 12),
                      const AppText(
                        'No Active Trip',
                        style: AppTextStyle.headlineSmall,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        'You don\'t have any running trip right now. View your assigned trips to start a journey.',
                        style: AppTextStyle.bodyMedium,
                        color: isDark ? Colors.white54 : AppColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'View Assigned Trips',
                        icon: Icons.arrow_forward_rounded,
                        isFullWidth: false,
                        onPressed: () => homeController.changeTabIndex(1),
                      ),
                    ],
                  ),
                );
              }
              
              final etaText = activeTrip.estimatedTime.isNotEmpty ? activeTrip.estimatedTime : 'Pending';
              final distText = activeTrip.remainingDistance.isNotEmpty ? ' (${activeTrip.remainingDistance})' : '';

              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: AppColors.surface.withValues(alpha: 0.2)),
                          child: const AppText('ACTIVE TRIP',
                              style: AppTextStyle.labelMedium,
                              color: AppColors.surface,
                              fontWeight: FontWeight.bold),
                        ),
                        AppText(
                          'ETA: $etaText$distText',
                          style: AppTextStyle.labelLarge,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'To ${activeTrip.dropCity}',
                      style: AppTextStyle.headlineSmall,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    const Divider(height: 24, color: Colors.white24),

                    // Source Terminal
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded,
                            color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            activeTrip.pickupLocation,
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Destination terminal
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            activeTrip.dropLocation,
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.bold,
                            color: AppColors.surface,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Resume navigation button
                    AppButton(
                      text: 'Resume Navigation',
                      icon: Icons.navigation_rounded,
                      type: AppButtonType.secondary,
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pushNamed(
                          Routes.TRIP_DETAILS,
                          arguments: {
                            'tripId': activeTrip.id,
                            'isAlreadyActive': true,
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // Quick Actions Panel
            const AppText('QUICK ACTIONS',
                style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildActionTile(
                  icon: Icons.article_outlined,
                  label: 'View Trips',
                  color: Colors.blue,
                  onTap: () => homeController.changeTabIndex(1),
                  isDark: isDark,
                ),
                _buildActionTile(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Start Trip',
                  color: Colors.green,
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(
                      Routes.TRIP_DETAILS,
                      arguments: {'tripId': 'TRP-882910'}),
                  isDark: isDark,
                ),
                _buildActionTile(
                  icon: Icons.my_location_rounded,
                  label: 'Update Location',
                  color: Colors.orange,
                  onTap: () => AppSnackBar.showSuccess(
                      title: 'GPS Updated',
                      message: 'Current coordinates matches NH-48.'),
                  isDark: isDark,
                ),
                _buildActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Upload Expense',
                  color: Colors.purple,
                  onTap: () => homeController.changeTabIndex(2),
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Emergency SOS Button
            AppButton(
              text: 'EMERGENCY SOS',
              icon: Icons.star_rounded,
              type: AppButtonType.inverted,
              height: 52,
              onPressed: controller.triggerEmergencySos,
            ),

            const SizedBox(height: 28),

            // Notifications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppText('NOTIFICATIONS',
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold),
                TextButton(
                  onPressed: () {},
                  child: const AppText('View All',
                      style: AppTextStyle.labelMedium,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.notifications.length,
              itemBuilder: (context, index) {
                final notif = controller.notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(notif.title,
                                  style: AppTextStyle.bodyLarge,
                                  fontWeight: FontWeight.bold),
                              AppText(notif.time,
                                  style: AppTextStyle.labelMedium),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppText(notif.body, style: AppTextStyle.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }),
);
}

  Widget _buildSummaryCard({
    required String title,
    required String Function() value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title,
                      style: AppTextStyle.labelMedium,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Obx(() => AppText(
                        value(),
                        style: AppTextStyle.bodyLarge,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              AppText(label,
                  style: AppTextStyle.labelLarge, fontWeight: FontWeight.bold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineView(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Truck Image with NO SIGNAL Badge Stack
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=600&auto=format&fit=crop',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Badge overlay: NO SIGNAL
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBE6).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        AppText(
                          'NO SIGNAL',
                          style: AppTextStyle.labelLarge,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 2. Main Title
          const AppText(
            "You're currently\noffline",
            textAlign: TextAlign.center,
            style: AppTextStyle.headlineLarge,
            fontWeight: FontWeight.w900,
            fontSize: 34,
          ),
          
          const SizedBox(height: 16),
          
          // 3. Subtitle Description
          AppText(
            "Don't worry, your trip data and updates are being saved locally. We'll sync everything automatically as soon as your connection returns.",
            textAlign: TextAlign.center,
            style: AppTextStyle.bodyMedium,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
          
          const SizedBox(height: 36),
          
          // 4. Retry Connection Button
          AppButton(
            text: 'Retry Connection',
            icon: Icons.sync_rounded,
            onPressed: controller.retryConnection,
          ),
          
          const SizedBox(height: 16),
          
          // 5. View Saved Trips Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.work_outline, color: AppColors.primary, size: 20),
              label: const AppText('View Saved Trips', style: AppTextStyle.labelLarge, color: AppColors.primary, fontWeight: FontWeight.bold),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFDEEBFF),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                final homeController = Get.find<HomeController>();
                homeController.changeTabIndex(1); // Switch to trips tab
              },
            ),
          ),
          
          const SizedBox(height: 36),
          
          // 6. Last Synced Pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFDEEBFF).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_outlined, color: isDark ? Colors.white70 : AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  AppText(
                    'Last synced: 10 mins ago',
                    style: AppTextStyle.labelMedium,
                    color: isDark ? Colors.white70 : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

