import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/trip_details_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/trip_status_timeline.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/session_service.dart';

/// Reference "Trip Status / Update Status" screen — the full journey timeline
/// with the current stage highlighted, the destination box (hidden until the
/// admin sets it and approves the load), and a single "Update Current Status"
/// button that drives the staged journey (same dispatcher as before).
class TripStatusView extends GetView<TripDetailsController> {
  const TripStatusView({super.key});

  String _driverName() {
    try {
      final name = Get.find<SessionService>().name.value;
      return name.isEmpty ? '' : name;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Trip Status',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        final status = controller.tripStatus.value;
        final done = TripStatusTimeline.doneCount(status);
        final data = controller.tripExtra.value ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripStatusTimeline(
                tripId: controller.tripId,
                status: status,
                driverName: _driverName(),
                truckNo: controller.vehicleNo.value,
                dropCity: (data['dropCity'] ?? '').toString(),
                milestonesLog: data['milestonesLog'] as List?,
                tripDate: (data['date'] ?? '').toString(),
              ),
              const SizedBox(height: 16),
              _destinationBox(isDark, data),
              const SizedBox(height: 16),
              _currentStatusBox(isDark, done),
              const SizedBox(height: 16),
              if (status != 'DELIVERED')
                ElevatedButton.icon(
                  onPressed: controller.startJourney,
                  icon: const Icon(Icons.published_with_changes_rounded,
                      size: 18),
                  label: Obx(() => Text(controller.primaryActionLabel)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              Obx(() => controller.showCallAdmin.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: controller.callAdmin,
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call Admin — destination set nahi hua'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        );
      }),
    );
  }

  /// Amber "admin will set destination" note until revealed; green destination
  /// card with Open in Maps once the load is approved.
  Widget _destinationBox(bool isDark, Map<String, dynamic> data) {
    final revealed = controller.destinationRevealed;
    final dropCity = (data['dropCity'] ?? '').toString();
    final dropLocation = (data['dropLocation'] ?? '').toString();
    final customerName = (data['customerName'] ?? '').toString();
    final customerAddress = (data['customerAddress'] ?? '').toString();

    if (!revealed || (dropCity.isEmpty && dropLocation.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tertiaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tertiary),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_rounded, color: AppColors.tertiaryDark, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('Admin will set destination',
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tertiaryDark),
                  AppText(
                      'Destination will be visible after loading is completed.',
                      style: AppTextStyle.labelMedium,
                      color: AppColors.tertiaryDark),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final lat = (data['dropLatitude'] as num?)?.toDouble();
    final lng = (data['dropLongitude'] as num?)?.toDouble();
    final query = lat != null && lng != null
        ? '$lat,$lng'
        : Uri.encodeComponent('$dropLocation, $dropCity');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Destination Location',
              style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText('$dropLocation, $dropCity',
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (customerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            AppText('Customer: $customerName', style: AppTextStyle.labelMedium),
          ],
          if (customerAddress.isNotEmpty)
            AppText('Address: $customerAddress',
                style: AppTextStyle.labelMedium),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await launchUrl(
                  Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$query'),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Open in Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentStatusBox(bool isDark, int done) {
    final current = done >= TripStatusTimeline.stages.length
        ? 'Trip Completed'
        : TripStatusTimeline.stages[done];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Current Status', style: AppTextStyle.labelMedium),
          const SizedBox(height: 2),
          AppText(current,
              style: AppTextStyle.bodyLarge,
              color: AppColors.info,
              fontWeight: FontWeight.w700),
        ],
      ),
    );
  }
}
