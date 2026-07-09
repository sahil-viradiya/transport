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
              _vehicleCard(p, trip, isDark),
              const SizedBox(height: 16),
              if (trip != null) _tripCard(context, trip, isDark) else _noTrip(isDark),
              if (p['documents'] != null && (p['documents'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                _documentsCard(p['documents'] as List, isDark),
              ],
              if (controller.expenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                _expensesCard(isDark),
              ],
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

  Widget _vehicleCard(Map<String, dynamic> p, Map<String, dynamic>? trip, bool isDark) {
    var vehicleNo = (p['vehicleNo'] ?? '').toString().trim();
    if (vehicleNo.isEmpty || vehicleNo == 'No vehicle') {
      vehicleNo = (trip?['truckNo'] ?? 'No vehicle').toString();
    }
    final vehicleModel = p['vehicleModel'] ?? '';
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
                AppText(vehicleNo,
                    style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
                if (vehicleModel.toString().isNotEmpty)
                  AppText(vehicleModel.toString(),
                      style: AppTextStyle.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context, Map<String, dynamic> trip, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pushNamed(
          Routes.TRIP_DETAILS,
          arguments: {
            'tripId': trip['id']?.toString() ?? '',
            'isAlreadyActive': trip['isActive'] == true,
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 14),
            TripProgressTracker(trip: trip),
          ],
        ),
      ),
    );
  }

  Widget _documentsCard(List<dynamic> documents, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('DOCUMENTS',
              style: AppTextStyle.labelMedium,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final doc = Map<String, dynamic>.from(documents[index] ?? {});
              final title = (doc['title'] ?? 'Document').toString();
              final subtitle = (doc['subtitle'] ?? '').toString();
              final expiry = (doc['expiryDate'] ?? '').toString();
              final status = (doc['status'] ?? '').toString();
              final isExpired = status == 'Expired';

              IconData iconData = Icons.description_rounded;
              if (title.toLowerCase().contains('license')) {
                iconData = Icons.badge_rounded;
              } else if (title.toLowerCase().contains('rc') || title.toLowerCase().contains('registration')) {
                iconData = Icons.local_shipping_rounded;
              }

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(title, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                        if (subtitle.isNotEmpty)
                          AppText(subtitle, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isExpired ? AppColors.error : AppColors.success).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AppText(status,
                            style: AppTextStyle.labelMedium,
                            color: isExpired ? AppColors.error : AppColors.success,
                            fontWeight: FontWeight.bold),
                      ),
                      if (expiry.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        AppText('Expiry: $expiry', style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// This driver's expense claims — title, amount and approval status.
  Widget _expensesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('EXPENSES',
              style: AppTextStyle.labelMedium,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.expenses.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, i) {
              final e = controller.expenses[i];
              final status = (e['status'] ?? 'Pending').toString();
              final color = status == 'Approved'
                  ? AppColors.success
                  : (status == 'Rejected'
                      ? AppColors.error
                      : AppColors.tertiaryDark);
              return InkWell(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pushNamed(
                    Routes.EXPENSE_DETAIL,
                    arguments: {
                      'id': e['id']?.toString() ?? '',
                    },
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt_long_rounded,
                            color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText((e['title'] ?? 'Expense').toString(),
                                style: AppTextStyle.bodyMedium,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if ((e['tripId'] ?? '').toString().isNotEmpty)
                              AppText('Trip: ${e['tripId']}',
                                  style: AppTextStyle.labelMedium,
                                  color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppText((e['amount'] ?? '').toString(),
                                  style: AppTextStyle.bodyMedium,
                                  fontWeight: FontWeight.w700),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: AppText(status,
                                    style: AppTextStyle.labelMedium,
                                    color: color,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
