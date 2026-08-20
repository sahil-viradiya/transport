import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/utils/image_url.dart';
import '../../home/controllers/home_controller.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/notification_bell.dart';
import '../../../data/notifications_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';

/// Reference driver dashboard: greeting header, green My Truck card, Today's
/// Trip + Trip Status tiles, 6-tile action grid, Trip Progress stepper card
/// and the duty check-in card. All previous functionality stays reachable.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(corsSafeImageUrl(path));
    } else if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
      return FileImage(File(path));
    }
    return const NetworkImage(
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning 👋';
    if (h < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  static String friendlyStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending Accept';
      case 'ASSIGNED':
        return 'Accepted';
      case 'EN_ROUTE_VENDOR':
        return 'On The Way';
      case 'LOADING':
        return 'Loading';
      case 'LOAD_REQUESTED':
        return 'Load Requested';
      case 'LOAD_REJECTED':
        return 'Rejected - Reupload Required';
      case 'ACTIVE NOW':
        return 'On The Way (Dest.)';
      case 'DELIVERY_REQUESTED':
        return 'Delivery Requested';
      case 'DELIVERY_REJECTED':
        return 'Delivery Rejected - Reupload POD Required';
      case 'DELIVERED':
        return 'Completed';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final home = Get.find<HomeController>();

    return Scaffold(
      body: Obx(() {
        if (!controller.isOnline.value) {
          return SafeArea(child: _buildOfflineView(context, isDark));
        }
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.loadProfileFromFirebase,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildMyTruckCard(),
                  _buildTruckAcceptanceAlert(),
                  const SizedBox(height: 12),
                  _buildReturnToStationCard(context),
                  _buildTodayTiles(context),
                  const SizedBox(height: 16),

                  _buildActionGrid(context, home),
                  const SizedBox(height: 16),
                  _buildTripProgressCard(context),
                  const SizedBox(height: 16),
                  _buildDutyCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTruckAcceptanceAlert() {
    return Obx(() {
      final status = controller.truckInspection;
      if (status != 'approved_pending_accept') return const SizedBox.shrink();
      final truckNo = controller.myTruckNo;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.primaryDark, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'Inspection Approved! 🚛',
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppText(
              'Admin ne truck $truckNo ka inspection approve kar diya hai. Trip shuru karne ke liye truck accept karein.',
              style: AppTextStyle.labelMedium,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: controller.acceptMyTruck,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Accept Truck',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  // ---- Greeting header (avatar + name + bell + SOS) ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Obx(() => CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: _getImageProvider(controller.avatarUrl.value),
            )),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(_greeting(),
                  style: AppTextStyle.labelMedium,
                  color: AppColors.textSecondary),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => AppText(
                          controller.driverName.value.isEmpty
                              ? 'Driver'
                              : controller.driverName.value,
                          style: AppTextStyle.titleLarge,
                          fontWeight: FontWeight.w800,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ),
                  // if (Get.isRegistered<ClockInService>())
                  //   Obx(() {
                  //     final cs = Get.find<ClockInService>();
                  //     if (!cs.isClockedIn.value) return const SizedBox.shrink();
                  //     return Container(
                  //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  //       decoration: BoxDecoration(
                  //         color: AppColors.primary.withOpacity(0.12),
                  //         borderRadius: BorderRadius.circular(12),
                  //         border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  //       ),
                  //       child: Row(
                  //         children: [
                  //           const CircleAvatar(radius: 3.5, backgroundColor: AppColors.primary),
                  //           const SizedBox(width: 5),
                  //           Text(
                  //             'On Duty • ${cs.shiftDurationText.value}',
                  //             style: const TextStyle(
                  //               fontSize: 11,
                  //               fontWeight: FontWeight.bold,
                  //               color: AppColors.primary,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     );
                  //   }),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: controller.triggerEmergencySos,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.sos_rounded, color: AppColors.error, size: 20),
          ),
        ),
        const NotificationBell(color: AppColors.textPrimary),
      ],
    );
  }

  // ---- Green "My Truck" card ----
  Widget _buildMyTruckCard() {
    return Obx(() {
      final truck = controller.myTruck.value;
      final truckNo = (truck?['truckNo'] ?? controller.vehicleNo.value).toString().trim();
      final model = (truck?['model'] ?? controller.vehicleModel.value).toString().trim();
      final hasTruck = truck != null && truckNo.isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasTruck ? AppColors.saffronGradient : [const Color(0xFF334155), const Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('My Truck',
                      style: AppTextStyle.labelMedium,
                      color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(height: 4),
                  AppText(hasTruck ? truckNo : 'No Truck Assigned',
                      style: AppTextStyle.headlineSmall,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  AppText(hasTruck ? (model.isNotEmpty ? model : 'Ready for Duty') : 'Waiting for Admin Allocation',
                      style: AppTextStyle.labelMedium,
                      color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      );
    });
  }

  // ---- Today's Trip + Trip Status tiles ----
  Widget _buildTodayTiles(BuildContext context) {
    return Obx(() {
      final trip = controller.currentTrip;
      final status = friendlyStatus(trip?.status ?? '');
      return Row(
        children: [
          Expanded(
            child: _miniTile(
              context,
              label: "Today's Trip",
              value: trip?.id ?? 'No Trip',
              sub: trip != null ? status : '—',
              icon: Icons.assignment_rounded,
              tint: const Color(0xFF7E22CE),
              onTap: trip == null
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).pushNamed(
                        Routes.TRIP_DETAILS,
                        arguments: {
                          'tripId': trip.id,
                          'isAlreadyActive': trip.isActive
                        },
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _miniTile(
              context,
              label: 'Trip Status',
              value: status,
              sub: trip != null ? trip.id : '—',
              icon: Icons.location_on_rounded,
              tint: AppColors.info,
              onTap: null,
            ),
          ),
        ],
      );
    });
  }

  Widget _miniTile(BuildContext context,
      {required String label,
      required String value,
      required String sub,
      required IconData icon,
      required Color tint,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(label, style: AppTextStyle.labelMedium, color: tint),
                  const SizedBox(height: 2),
                  AppText(value,
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.w800,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  AppText(sub,
                      style: AppTextStyle.labelMedium,
                      color: AppColors.textHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(icon, color: tint, size: 20),
          ],
        ),
      ),
    );
  }

  // ---- 6-tile action grid ----
  Widget _buildActionGrid(BuildContext context, HomeController home) {
    Widget tile(IconData icon, String label, Color color, VoidCallback onTap,
        {int badge = 0}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: AppText('$badge',
                            style: AppTextStyle.labelMedium,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              AppText(label,
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.w600,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Obx(() {
      final inspectionBadge = (controller.myTruck.value != null &&
              controller.truckInspection != 'ready')
          ? 1
          : 0;
      final notifBadge = Get.isRegistered<NotificationsController>()
          ? Get.find<NotificationsController>().unreadCount
          : 0;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          tile(Icons.local_shipping_rounded, 'my_trips'.tr, AppColors.primary, () {
            if (!controller.ensureCheckedIn()) return;
            home.changeTabIndex(1);
          }),
          tile(Icons.fact_check_rounded, 'inspection'.tr, AppColors.info, () {
            if (!controller.ensureCheckedIn()) return;
            home.changeTabIndex(3);
          }, badge: inspectionBadge),
          tile(Icons.workspace_premium_rounded, 'pass_and_royalty'.tr,
              const Color(0xFF7E22CE), () {
            if (!controller.ensureCheckedIn()) return;
            final trip = controller.currentTrip;
            if (trip == null) {
              AppSnackBar.showInfo(
                  title: 'No Trip', message: 'Abhi koi trip assigned nahi.');
              return;
            }
            Navigator.of(context, rootNavigator: true).pushNamed(
              Routes.TRIP_DETAILS,
              arguments: {'tripId': trip.id, 'isAlreadyActive': trip.isActive},
            );
          }),
          tile(Icons.description_rounded, 'driver_documents'.tr, AppColors.tertiaryDark,
              () {
            if (!controller.ensureCheckedIn()) return;
            home.changeTabIndex(4);
            try {
              Get.find<ProfileController>().selectSubTab(1);
            } catch (_) {}
          }),
          tile(Icons.currency_rupee_rounded, 'earnings'.tr, AppColors.success, () {
            if (!controller.ensureCheckedIn()) return;
            home.changeTabIndex(2);
          }),
          tile(Icons.notifications_rounded, 'notifications'.tr, AppColors.error,
              () {
            if (!controller.ensureCheckedIn()) return;
            const NotificationBell().open(context);
          }, badge: notifBadge),
        ],
      );
    });
  }

  // ---- Trip Progress stepper card (5 reference stages) ----
  Widget _buildTripProgressCard(BuildContext context) {
    return Obx(() {
      final trip = controller.currentTrip;
      if (trip == null) return const SizedBox.shrink();

      const labels = [
        'On The\nWay',
        'Reached\nVendor',
        'Loading',
        'On The Way\n(Dest.)',
        'Completed'
      ];
      // stage index reached (0-based); current = next
      int done;
      String info;
      switch (trip.status) {
        case 'EN_ROUTE_VENDOR':
          done = 0;
          info =
              'You are on the way to ${trip.vendorLocation.isEmpty ? trip.pickupLocation : trip.vendorLocation}';
          break;
        case 'LOADING':
        case 'LOAD_REJECTED':
          done = 2;
          info = trip.status == 'LOAD_REJECTED'
              ? 'Loading photo rejected — re-upload required'
              : 'Truck is loading at ${trip.vendorName.isEmpty ? 'vendor' : trip.vendorName}';
          break;
        case 'LOAD_REQUESTED':
          done = 3;
          info = 'Loading complete — waiting for admin approval';
          break;
        case 'ACTIVE NOW':
        case 'DELIVERY_REQUESTED':
        case 'DELIVERY_REJECTED':
          done = 4;
          info = trip.status == 'DELIVERY_REJECTED'
              ? 'Delivery proof rejected — re-upload POD required'
              : trip.dropCity.isEmpty
                  ? 'On the way to destination'
                  : 'On the way to ${trip.dropCity}';
          break;
        case 'DELIVERED':
          done = 5;
          info = 'Trip completed. Great job!';
          break;
        default:
          done = 0;
          info = 'Trip assigned — accept & start when ready';
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Trip Progress',
                style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w800),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(info,
                        style: AppTextStyle.labelMedium,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(labels.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final idx = i ~/ 2;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(top: 11),
                      color: idx < done ? AppColors.success : AppColors.border,
                    ),
                  );
                }
                final idx = i ~/ 2;
                final isDone = idx < done;
                final isCurrent = idx == done && trip.status != 'DELIVERED';
                final color = isDone
                    ? AppColors.success
                    : (isCurrent ? AppColors.info : AppColors.textHint);
                return Column(
                  children: [
                    Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.radio_button_checked_rounded
                                : Icons.circle_outlined),
                        size: 24,
                        color: color),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: AppText(labels[idx],
                          style: AppTextStyle.labelMedium,
                          textAlign: TextAlign.center,
                          color: color,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 14),
            AppButton(
              text: 'Update Status',
              icon: Icons.published_with_changes_rounded,
              onPressed: () {
                // Switch to Trips Tab (index 1)
                Get.find<HomeController>().changeTabIndex(1);
                // Scroll to the active trip card
                Get.find<TripsController>().scrollToActiveTrip(trip.id);
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildReturnToStationCard(BuildContext context) {
    return Obx(() {
      final isClocked = controller.dutyStatus.value != 'off_duty';
      if (!isClocked) return const SizedBox.shrink();

      final hasCompletedAll = controller.hasCompletedAllTrips;
      final status = controller.returnJourneyStatus.value;
      final duty = controller.dutyStatus.value;

      if (hasCompletedAll && status == 'none') {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'All Trips Completed! 🎉',
                      style: AppTextStyle.titleLarge,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const AppText(
                'Aapne aaj ki sabhi trips puri kar li hain. Station wapas lautne ke liye niche button dabayein.',
                style: AppTextStyle.bodyMedium,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: controller.startReturnJourney,
                icon: const Icon(Icons.directions_bus_rounded, color: AppColors.primaryDark),
                label: const Text('Return to Transport Station',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }

      if (status == 'in_transit' || status == 'rejected' || duty == 'RETURNING_TO_STATION') {
        final isRejected = status == 'rejected';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRejected
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isRejected ? AppColors.error : AppColors.info,
                width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isRejected
                        ? Icons.cancel_rounded
                        : Icons.directions_bus_rounded,
                    color: isRejected ? AppColors.error : AppColors.info,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      isRejected
                          ? 'Parking Confirmation Rejected'
                          : 'Returning to Station 🚛',
                      style: AppTextStyle.titleLarge,
                      fontWeight: FontWeight.bold,
                      color: isRejected ? AppColors.error : AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AppText(
                isRejected
                    ? 'Reason: ${controller.parkingConfirmation.value?['rejectionReason'] ?? 'Details incorrect'}. Kripya dobara truck photo submit karein.'
                    : 'Aap transport station ke raste mein hain. Pahuche par parking confirmation request submit karein.',
                style: AppTextStyle.bodyMedium,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () =>
                    controller.openParkingConfirmationDialog(context),
                icon: const Icon(Icons.local_parking_rounded),
                label: Text(
                    isRejected
                        ? 'Re-submit Parking Confirmation'
                        : 'Submit Parking Confirmation',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isRejected ? AppColors.error : AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }

      if (status == 'parking_requested' || duty == 'PARKING_PENDING') {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: AppColors.warning, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'Parking Verification Pending ⏳',
                      style: AppTextStyle.titleLarge,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const AppText(
                'Aapka parking request admin verification ke liye bhej diya gaya hai. Admin approval ke baad aap Clock Out kar payenge.',
                style: AppTextStyle.bodyMedium,
              ),
            ],
          ),
        );
      }

      if (status == 'verified' || duty == 'STATION_VERIFIED') {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded,
                      color: AppColors.success, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'Station Verified ✅',
                      style: AppTextStyle.titleLarge,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const AppText(
                'Admin ne aapka parking approve kar diya hai. Aapka workday safaltapoorvak pura ho gaya hai.',
                style: AppTextStyle.bodyMedium,
              ),
              const SizedBox(height: 10),
              Obx(() {
                final remaining = controller.autoClockOutRemainingText.value;
                if (remaining.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(
                          'Auto Clock Out in: $remaining (3h Limit)',
                          style: AppTextStyle.labelMedium,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: controller.checkOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Clock Out Now',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }

      return const SizedBox.shrink();
    });
  }

  // ---- Duty / Check-in card (kept from before) ----
  Widget _buildDutyCard(BuildContext context) {

    return Obx(() {
      final onDuty = controller.isOnDuty;
      final accent = onDuty ? AppColors.success : AppColors.textSecondary;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    onDuty
                        ? Icons.check_circle_rounded
                        : Icons.nightlight_round,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(onDuty ? 'On Duty • Available' : 'Off Duty',
                          style: AppTextStyle.titleLarge,
                          fontWeight: FontWeight.w700,
                          color: accent),
                      const SizedBox(height: 2),
                      AppText(
                        onDuty
                            ? (controller.checkInAddress.value.isNotEmpty
                                ? '📍 ${controller.checkInAddress.value}'
                                : 'You are marked available to admin.')
                            : 'Check in to mark yourself available for trips.',
                        style: AppTextStyle.labelMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: onDuty
                  ? OutlinedButton.icon(
                      onPressed: controller.checkOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Check Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: controller.checkIn,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
    );
  }

  Widget _buildOfflineView(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: AppColors.charcoalGradient),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 44),
                  SizedBox(height: 10),
                  AppText('NO SIGNAL',
                      style: AppTextStyle.labelLarge,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const AppText("You're offline",
              textAlign: TextAlign.center,
              style: AppTextStyle.headlineLarge,
              fontWeight: FontWeight.w800),
          const SizedBox(height: 12),
          AppText(
            'Chinta mat karein — aapka data locally save ho raha hai. Connection aate hi sab sync ho jayega.',
            textAlign: TextAlign.center,
            style: AppTextStyle.bodyMedium,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
          const SizedBox(height: 28),
          AppButton(
            text: 'Retry Connection',
            icon: Icons.sync_rounded,
            onPressed: controller.retryConnection,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.work_outline_rounded, size: 20),
            label: const Text('View Saved Trips'),
            onPressed: () => Get.find<HomeController>().changeTabIndex(1),
          ),
        ],
      ),
    );
  }
}
