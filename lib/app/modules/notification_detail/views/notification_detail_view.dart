import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/notification_detail_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/trip_progress_tracker.dart';
import '../../../../widgets/feedback_views.dart';
import '../../../../widgets/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/utils/app_image_helper.dart';

class NotificationDetailView extends GetView<NotificationDetailController> {
  const NotificationDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Notification',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppLoadingView();
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(isDark),
              const SizedBox(height: 16),
              if (controller.trip.value != null) _tripCard(context, isDark),
              if (controller.trip.value != null &&
                  (controller.trip.value!['podUrl'] ?? '')
                      .toString()
                      .startsWith('http'))
                _podProofCard(controller.trip.value!, isDark),
              if (controller.expense.value != null) _expenseCard(isDark),
              if (controller.truck.value != null) _truckCard(isDark),
              if (controller.parkingRequest.value != null)
                _parkingConfirmationCard(controller.parkingRequest.value!, isDark),
              const SizedBox(height: 20),
              _actionSection(),
            ],
          ),
        );
      }),
    );
  }


  Widget _card(bool isDark, Widget child) => AppCard(child: child);

  Widget _headerCard(bool isDark) {
    final (icon, tint) = _style(controller.type);
    return _card(
      isDark,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(controller.title,
                    style: AppTextStyle.titleLarge,
                    fontWeight: FontWeight.w700),
                const SizedBox(height: 4),
                AppText(controller.body, style: AppTextStyle.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context, bool isDark) {
    final t = controller.trip.value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppText('Trip ${controller.tripId}',
                    style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: AppText(t['status']?.toString() ?? '',
                      style: AppTextStyle.labelMedium,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('FROM', style: AppTextStyle.labelMedium),
                      AppText(t['pickupCity']?.toString() ?? '',
                          style: AppTextStyle.titleLarge,
                          fontWeight: FontWeight.w700),
                    ],
                  ),
                ),
                const Icon(Icons.east_rounded, color: AppColors.primary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppText('TO', style: AppTextStyle.labelMedium),
                      AppText(t['dropCity']?.toString() ?? '',
                          style: AppTextStyle.titleLarge,
                          fontWeight: FontWeight.w700,
                          textAlign: TextAlign.end),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TripProgressTracker(trip: t),
          ],
        ),
      ),
    );
  }

  /// The uploaded Proof-of-Delivery photo + driver remarks, shown to the admin
  /// so they can verify the proof before approving the delivery.
  Widget _podProofCard(Map<String, dynamic> trip, bool isDark) {
    final podUrl = trip['podUrl'].toString();
    final remarks = (trip['remarks'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 18),
                SizedBox(width: 8),
                AppText('PROOF OF DELIVERY',
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                corsSafeImageUrl(podUrl),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textHint),
                ),
              ),
            ),
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText('Driver remarks: $remarks',
                  style: AppTextStyle.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  /// Truck context for truck_assigned / truck_issue / truck_ready — shows the
  /// inspection status and, for problems, the reported reason + photo proof.
  Widget _truckCard(bool isDark) {
    final t = controller.truck.value!;
    final inspection = (t['inspectionStatus'] ?? '').toString();
    final issue = (t['inspectionIssue'] ?? '').toString();
    final issueImage = (t['inspectionIssueImage'] ?? '').toString();
    final (color, label) = switch (inspection) {
      'ready' => (AppColors.success, 'Ready ✓'),
      'problem' => (AppColors.error, 'Problem Reported'),
      _ => (AppColors.tertiaryDark, 'Inspection Pending'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText((t['truckNo'] ?? '').toString(),
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.w700),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(label,
                      style: AppTextStyle.labelMedium,
                      color: color,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if ((t['model'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              AppText((t['model'] ?? '').toString(),
                  style: AppTextStyle.labelMedium),
            ],
            if (issue.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText('⚠️ Problem: $issue',
                  style: AppTextStyle.bodyMedium,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600),
            ],
            if (issueImage.startsWith('http')) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  corsSafeImageUrl(issueImage),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded,
                        color: AppColors.textHint),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(bool isDark) {
    final e = controller.expense.value!;
    final receipt = e['receiptUrl']?.toString() ?? '';
    final status = e['status']?.toString() ?? 'Pending';
    final statusColor = status == 'Approved'
        ? AppColors.success
        : (status == 'Rejected' ? AppColors.error : AppColors.tertiaryDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(e['title']?.toString() ?? 'Expense',
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.w700),
                ),
                AppText(e['amount']?.toString() ?? '',
                    style: AppTextStyle.titleLarge,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 4),
            AppText(e['description']?.toString() ?? '',
                style: AppTextStyle.bodyMedium),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: AppText(status,
                    style: AppTextStyle.labelMedium,
                    color: statusColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (receipt.isNotEmpty) ...[
              const SizedBox(height: 12),
              const AppText('RECEIPT PROOF',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(corsSafeImageUrl(receipt),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.textHint),
                        )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Called inside the build's outer Obx (which already observes trip/expense),
  // so this must NOT wrap in its own Obx.
  Widget _actionSection() {
    final action = controller.availableAction;
    if (action.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_rounded, color: AppColors.textSecondary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: AppText('No action needed — already handled.',
                  style: AppTextStyle.bodyMedium),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.promptReject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: controller.approve,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _parkingConfirmationCard(Map<String, dynamic> p, bool isDark) {
    final driverName = (p['driverName'] ?? 'Driver').toString();
    final driverId = (p['driverId'] ?? '').toString();
    final vehicleNo = (p['vehicleNo'] ?? '').toString();
    final address = (p['address'] ?? '').toString();
    final timeStr = (p['arrivalTime'] ?? '').toString();
    final photoUrl = (p['truckPhotoUrl'] ?? '').toString();
    final distanceKm = (p['distanceKm'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_parking_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const AppText('Parking Request Details', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(
                    p['status']?.toString() ?? 'PENDING',
                    style: AppTextStyle.labelMedium,
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Driver', '$driverName ($driverId)'),
            _infoRow('Truck No', vehicleNo),
            _infoRow('Arrival Time', timeStr),
            _infoRow('Arrival Location', address),
            _infoRow('Station Distance', '${distanceKm.toStringAsFixed(2)} km away'),
            if (photoUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              const AppText('Truck Parking Photo:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photoUrl.startsWith('data:image/')
                    ? Image.memory(
                        AppImageHelper.decodeBase64(photoUrl)!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        corsSafeImageUrl(photoUrl),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image_rounded)),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: AppText(label, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
          ),
          Expanded(
            child: AppText(value, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _style(String type) {
    switch (type) {
      case 'trip_assigned':
        return (Icons.local_shipping_rounded, AppColors.primary);
      case 'load_request':
        return (Icons.inventory_2_rounded, AppColors.tertiaryDark);
      case 'delivery_request':
        return (Icons.where_to_vote_rounded, AppColors.primary);
      case 'parking_confirmation_request':
        return (Icons.local_parking_rounded, AppColors.primary);
      case 'expense_submitted':
        return (Icons.receipt_long_rounded, AppColors.tertiaryDark);
      case 'trip_accepted':
      case 'trip_activated':
      case 'delivery_approved':
      case 'expense_approved':
      case 'parking_approved':
        return (Icons.check_circle_rounded, AppColors.success);
      case 'trip_rejected':
      case 'load_rejected':
      case 'delivery_rejected':
      case 'expense_rejected':
      case 'parking_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      default:
        return (Icons.notifications_rounded, AppColors.tertiaryDark);
    }
  }
}

