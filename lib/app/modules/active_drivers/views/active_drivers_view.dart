import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../admin_home/controllers/admin_home_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';

/// List of drivers currently on duty (Available) or running an active trip.
/// Tapping a driver opens their detail screen. Reuses the live AdminHome data.
class ActiveDriversView extends GetView<AdminHomeController> {
  const ActiveDriversView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Active Drivers',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        final drivers = controller.activeDrivers;
        if (drivers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_rounded,
                    size: 56, color: AppColors.textHint),
                SizedBox(height: 12),
                AppText('No active drivers right now.',
                    style: AppTextStyle.bodyLarge),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _driverCard(drivers[i], isDark),
        );
      }),
    );
  }

  Widget _driverCard(Map<String, dynamic> u, bool isDark) {
    final phone = (u['phone'] ?? '').toString();
    final name = (u['name'] ?? 'Driver').toString();
    final available = u['availability'] == 'available' || u['checkedIn'] == true;
    final trip = controller.activeTripForDriver(phone);
    final onTrip = trip != null;

    return InkWell(
      onTap: () => controller.openDriverDetail(phone),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1B18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? const Color(0xFF332E2A) : AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: (u['avatarUrl'] ?? '').toString().startsWith('http')
                  ? NetworkImage(u['avatarUrl'])
                  : null,
              child: (u['avatarUrl'] ?? '').toString().startsWith('http')
                  ? null
                  : const Icon(Icons.person_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(name,
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  AppText(phone, style: AppTextStyle.labelMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(
                        available ? 'Available' : 'On Duty',
                        available ? AppColors.success : AppColors.textSecondary,
                        available ? Icons.circle : Icons.circle_outlined,
                      ),
                      if (onTrip) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _chip(
                            '${trip['pickupCity'] ?? ''} → ${trip['dropCity'] ?? ''}',
                            AppColors.primary,
                            Icons.local_shipping_rounded,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: AppText(label,
                style: AppTextStyle.labelMedium,
                color: color,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
