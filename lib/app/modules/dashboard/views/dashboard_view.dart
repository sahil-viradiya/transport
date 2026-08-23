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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Obx(() => CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFDCFCE7),
              backgroundImage: _getImageProvider(controller.avatarUrl.value),
            )),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Obx(() => Text(
                    controller.driverName.value.isEmpty
                        ? 'Driver'
                        : controller.driverName.value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
            ],
          ),
        ),
        GestureDetector(
          onTap: controller.triggerEmergencySos,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SOS',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        NotificationBell(color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF16A34A),
              Color(0xFF15803D),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Truck',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasTruck ? truckNo : 'No Truck Assigned',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasTruck
                        ? (model.isNotEmpty ? model : 'Ready for Duty')
                        : 'Waiting for Admin Allocation',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ---- Today's Trip + Trip Status tiles ----
  Widget _buildTodayTiles(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final trip = controller.currentTrip;
      final status = friendlyStatus(trip?.status ?? '');
      final tripId = trip?.id ?? 'No Trip';

      return Row(
        children: [
          // Tile 1: Today's Trip
          Expanded(
            child: InkWell(
              onTap: trip == null
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).pushNamed(
                        Routes.TRIP_DETAILS,
                        arguments: {
                          'tripId': trip.id,
                          'isAlreadyActive': trip.isActive
                        },
                      ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E1065).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.purple.shade900 : const Color(0xFFF3E8FF),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Trip",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9333EA),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tripId,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null ? status : '—',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFF9333EA),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Tile 2: Trip Status
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF172554).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade900 : const Color(0xFFDBEAFE),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip Status',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip != null ? trip.id : '—',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ---- 6-tile action grid ----
  Widget _buildActionGrid(BuildContext context, HomeController home) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile(IconData icon, String label, Color iconColor, Color iconBg, VoidCallback onTap,
        {int badge = 0}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                 clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
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
        childAspectRatio: 1.14,
        children: [
          tile(
            Icons.local_shipping_rounded,
            'my_trips'.tr,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            () {
              if (!controller.ensureCheckedIn()) return;
              home.changeTabIndex(1);
            },
          ),
          tile(
            Icons.fact_check_rounded,
            'inspection'.tr,
            const Color(0xFF2563EB),
            const Color(0xFFEFF6FF),
            () {
              if (!controller.ensureCheckedIn()) return;
              home.changeTabIndex(3);
            },
            badge: inspectionBadge,
          ),
          tile(
            Icons.workspace_premium_rounded,
            'pass_and_royalty'.tr,
            const Color(0xFF7E22CE),
            const Color(0xFFFAF5FF),
            () {
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
            },
          ),
          tile(
            Icons.description_rounded,
            'driver_documents'.tr,
            const Color(0xFFEA580C),
            const Color(0xFFFFF7ED),
            () {
              if (!controller.ensureCheckedIn()) return;
              home.changeTabIndex(4);
              try {
                Get.find<ProfileController>().selectSubTab(1);
              } catch (_) {}
            },
          ),
          tile(
            Icons.currency_rupee_rounded,
            'earnings'.tr,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            () {
              if (!controller.ensureCheckedIn()) return;
              home.changeTabIndex(2);
            },
          ),
          tile(
            Icons.notifications_rounded,
            'notifications'.tr,
            const Color(0xFFDC2626),
            const Color(0xFFFEE2E2),
            () {
              if (!controller.ensureCheckedIn()) return;
              const NotificationBell().open(context);
            },
            badge: notifBadge,
          ),
        ],
      );
    });
  }

  // ---- Trip Progress stepper card (5 reference stages) ----
  Widget _buildTripProgressCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trip Progress',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: Color(0xFF2563EB), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      height: 2,
                      margin: const EdgeInsets.only(top: 10),
                      color: idx < done ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                    ),
                  );
                }
                final idx = i ~/ 2;
                final isDone = idx < done;
                final isCurrent = idx == done && trip.status != 'DELIVERED';
                final color = isDone
                    ? const Color(0xFF16A34A)
                    : (isCurrent ? const Color(0xFF2563EB) : const Color(0xFF94A3B8));
                return Column(
                  children: [
                     Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.radio_button_checked_rounded
                                : Icons.circle_outlined),
                        size: 20,
                        color: color),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 54,
                      child: Text(
                        labels[idx],
                        style: TextStyle(
                          fontSize: 9.5,
                          color: color,
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.w600,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Get.find<HomeController>().changeTabIndex(1);
                Get.find<TripsController>().scrollToActiveTrip(trip.id);
              },
              icon: const Icon(Icons.published_with_changes_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Update Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
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

  // ---- Duty / Check-in card ----
  Widget _buildDutyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final onDuty = controller.isOnDuty;
      final accent = onDuty ? const Color(0xFF16A34A) : const Color(0xFF64748B);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: onDuty ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                onDuty
                    ? Icons.check_circle_rounded
                    : Icons.nightlight_round,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onDuty ? 'On Duty • Available' : 'Off Duty',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onDuty
                        ? (controller.checkInAddress.value.isNotEmpty
                            ? '📍 ${controller.checkInAddress.value}'
                            : 'You are marked available to admin.')
                        : 'Check in to mark yourself available for trips.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            onDuty
                ? OutlinedButton.icon(
                    onPressed: controller.checkOut,
                    icon: const Icon(Icons.logout_rounded, size: 14, color: Color(0xFFDC2626)),
                    label: const Text(
                      'Check Out',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: controller.checkIn,
                    icon: const Icon(Icons.my_location_rounded, size: 14, color: Colors.white),
                    label: const Text(
                      'Check In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
          ],
        ),
      );
    });
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
