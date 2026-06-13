import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../../core/theme/app_colors.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pull driver controller details if active
    final driverController = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            
            // Driver Profile badge header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_pin_rounded,
                      size: 70,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    driverController.driverName.value,
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        AppText(
                          'ACTIVE DUTY',
                          style: AppTextStyle.labelMedium,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Profile info cards
            const AppText('TERMINAL & TRUCK DETAILS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileTile(Icons.phone_rounded, 'Mobile Number', driverController.driverPhone.value),
                    const Divider(height: 24),
                    _buildProfileTile(Icons.local_shipping_rounded, 'Assigned Truck', driverController.vehicleNo.value),
                    const Divider(height: 24),
                    _buildProfileTile(Icons.badge_rounded, 'License Number', 'DL-142023009871'),
                    const Divider(height: 24),
                    _buildProfileTile(Icons.business_center_rounded, 'Carrier Agency', 'Highway Express Logistics'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Settings options
            const AppText('SETTINGS & CONFIGURATIONS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToggleTile(Icons.notifications_active_outlined, 'Speed Limit Warnings', true),
                    const Divider(height: 24),
                    _buildToggleTile(Icons.gps_fixed_rounded, 'Share Live GPS Coordinates', true),
                    const Divider(height: 24),
                    _buildToggleTile(Icons.dark_mode_outlined, 'Night Mode Interface', isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Logout action button
            AppButton(
              text: 'Logout Terminal Session',
              type: AppButtonType.outlined,
              icon: Icons.power_settings_new_rounded,
              onPressed: driverController.logout,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String label, String value) {
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 12),
        AppText(label, style: AppTextStyle.bodyMedium),
        const Spacer(),
        AppText(
          value,
          style: AppTextStyle.bodyLarge,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildToggleTile(IconData icon, String label, bool value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: AppText(label, style: AppTextStyle.bodyMedium)),
        Switch(
          value: value,
          activeColor: AppColors.primary,
          onChanged: (val) {},
        ),
      ],
    );
  }
}
