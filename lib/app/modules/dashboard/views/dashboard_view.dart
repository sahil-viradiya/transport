import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import '../controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pull parent HomeController to switch tabs
    final homeController = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const AppText('The Highway Authority', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
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
            // Profile block
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('Welcome back,', style: AppTextStyle.bodyMedium),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.green, size: 10),
                      SizedBox(width: 4),
                      AppText('ACTIVE DUTY', style: AppTextStyle.labelMedium, color: Colors.green, fontWeight: FontWeight.bold),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Today's Truck & Trips summary cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'ASSIGNED TRUCK',
                    value: () => controller.vehicleNo.value,
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'TODAY\'S TRIPS',
                    value: () => controller.todayTripsCount.value.toString().padLeft(2, '0'),
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.tertiaryDark,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Active Trip Blue Gradient Box
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
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
                      const AppText('ACTIVE TRIP', style: AppTextStyle.labelMedium, color: Colors.white70, fontWeight: FontWeight.bold),
                      Obx(() => AppText('ETA ${controller.activeEta.value}', style: AppTextStyle.labelLarge, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() => AppText(
                        controller.activeDestination.value,
                        style: AppTextStyle.headlineSmall,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
                  const Divider(height: 24, color: Colors.white24),
                  
                  // Source Terminal
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked_rounded, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() => AppText(
                              controller.activeSourcePoint.value,
                              style: AppTextStyle.bodyMedium,
                              color: Colors.white70,
                            )),
                      ),
                    ],
                  ),
                  
                  // Line connector
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Container(width: 2, height: 16, color: Colors.white24),
                  ),
                  
                  // Destination terminal
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() => AppText(
                              controller.activeDestPoint.value,
                              style: AppTextStyle.bodyMedium,
                              color: Colors.white70,
                            )),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Resume navigation button
                  AppButton(
                    text: 'Resume Navigation',
                    icon: Icons.navigation_rounded,
                    type: AppButtonType.outlined,
                    onPressed: () => Get.toNamed(Routes.TRIP_DETAILS, arguments: {'tripId': 'TRP-882910'}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Panel
            const AppText('QUICK ACTIONS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
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
                  onTap: () => Get.toNamed(Routes.TRIP_DETAILS, arguments: {'tripId': 'TRP-882910'}),
                  isDark: isDark,
                ),
                _buildActionTile(
                  icon: Icons.my_location_rounded,
                  label: 'Update Location',
                  color: Colors.orange,
                  onTap: () => AppSnackBar.showSuccess(title: 'GPS Updated', message: 'Current coordinates matches NH-48.'),
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
                const AppText('NOTIFICATIONS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                TextButton(
                  onPressed: () {},
                  child: const AppText('View All', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
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
                              AppText(notif.title, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                              AppText(notif.time, style: AppTextStyle.labelMedium),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, style: AppTextStyle.labelMedium, overflow: TextOverflow.ellipsis),
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
              AppText(label, style: AppTextStyle.labelLarge, fontWeight: FontWeight.bold),
            ],
          ),
        ),
      ),
    );
  }
}
