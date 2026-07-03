import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/driver_detail_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/trip_progress_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';

class DriverDetailView extends GetView<DriverDetailController> {
  const DriverDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Driver Details',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final u = controller.user.value ?? {};
        final p = controller.profile.value ?? {};
        final trip = controller.activeTrip.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileCard(u, isDark),
              const SizedBox(height: 16),
              _vehicleCard(p, isDark),
              const SizedBox(height: 16),
              if (trip != null) _tripCard(trip, isDark) else _noTrip(isDark),
            ],
          ),
        );
      }),
    );
  }

  BoxDecoration _deco(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF1F1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF332E2A) : AppColors.border),
      );

  Widget _profileCard(Map<String, dynamic> u, bool isDark) {
    final name = (u['name'] ?? 'Driver').toString();
    final phone = (u['phone'] ?? controller.phone).toString();
    final available = u['availability'] == 'available';
    final avatar = (u['avatarUrl'] ?? '').toString();
    final checkInAddr = (u['checkInAddress'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryLight,
                backgroundImage:
                    avatar.startsWith('http') ? NetworkImage(avatar) : null,
                child: avatar.startsWith('http')
                    ? null
                    : const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(name,
                        style: AppTextStyle.headlineSmall,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    AppText(phone, style: AppTextStyle.bodyMedium),
                    const SizedBox(height: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (available
                                ? AppColors.success
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText(available ? 'Available' : 'Off Duty',
                          style: AppTextStyle.labelMedium,
                          color: available
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (available && checkInAddr.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_rounded,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText('Checked in at: $checkInAddr',
                      style: AppTextStyle.bodyMedium),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> p, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded,
              color: AppColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText((p['vehicleNo'] ?? 'No vehicle').toString(),
                    style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
                AppText((p['vehicleModel'] ?? '').toString(),
                    style: AppTextStyle.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(Map<String, dynamic> trip, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppText('CURRENT TRIP',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
              const Spacer(),
              AppText(trip['id']?.toString() ?? '',
                  style: AppTextStyle.labelMedium, fontWeight: FontWeight.w700),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppText('${trip['pickupCity'] ?? ''} → ${trip['dropCity'] ?? ''}',
                    style: AppTextStyle.titleLarge, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TripProgressTracker(trip: trip),
        ],
      ),
    );
  }

  Widget _noTrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: const Row(
        children: [
          Icon(Icons.info_rounded, color: AppColors.textSecondary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: AppText('No active trip right now.',
                style: AppTextStyle.bodyMedium),
          ),
        ],
      ),
    );
  }
}
