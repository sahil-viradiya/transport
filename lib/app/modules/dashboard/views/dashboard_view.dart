import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/premium_widgets.dart';
import '../../../../widgets/trip_progress_tracker.dart';
import '../../../../widgets/notification_bell.dart';
import '../../../data/notifications_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
      // File() is unsupported on web — only touch it on mobile/desktop.
      return FileImage(File(path));
    }
    return const NetworkImage(
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeController = Get.find<HomeController>();

    return Scaffold(
      body: Obx(() {
        if (!controller.isOnline.value) {
          return SafeArea(child: _buildOfflineView(context, isDark));
        }
        return RefreshIndicator(
          onRefresh: controller.loadProfileFromFirebase,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDutyCard(context),
                      const SizedBox(height: 16),
                      _buildActiveTripCard(context),
                      const SizedBox(height: 24),
                      const SectionHeader('Quick Actions'),
                      const SizedBox(height: 12),
                      _buildQuickActions(context, homeController),
                      const SizedBox(height: 24),
                      SectionHeader('Notifications',
                          actionLabel: 'View All', onAction: () {}),
                      const SizedBox(height: 12),
                      _buildNotifications(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---- Saffron gradient hero header ----
  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.saffronGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Obx(() => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
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
                        AppText('Ram Ram 🙏',
                            style: AppTextStyle.labelMedium,
                            color: Colors.white.withValues(alpha: 0.9)),
                        Obx(() => AppText(
                              controller.driverName.value.isEmpty
                                  ? 'Truck Owner'
                                  : controller.driverName.value,
                              style: AppTextStyle.titleLarge,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const NotificationBell(color: Colors.white),
                  _circleIcon(Icons.sos_rounded, controller.triggerEmergencySos,
                      bg: Colors.white.withValues(alpha: 0.18)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => HeroStat(
                          icon: Icons.local_shipping_rounded,
                          label: 'Vehicle',
                          value: controller.vehicleNo.value.isEmpty
                              ? '—'
                              : controller.vehicleNo.value,
                        )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => HeroStat(
                          icon: Icons.route_rounded,
                          label: 'Total Trips',
                          value: controller.todayTripsCount.value
                              .toString()
                              .padLeft(2, '0'),
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap, {required Color bg}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ---- Duty / Check-in card ----
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
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          AppText(onDuty ? 'On Duty • Available' : 'Off Duty',
                              style: AppTextStyle.titleLarge,
                              fontWeight: FontWeight.w700,
                              color: accent),
                        ],
                      ),
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

  // ---- Active trip card (white, with progress tracker) ----
  Widget _buildActiveTripCard(BuildContext context) {
    return Obx(() {
      final trip = controller.activeTrip;
      final homeController = Get.find<HomeController>();

      if (trip == null) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: _cardDecoration(context),
          child: Column(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  color: AppColors.textHint, size: 44),
              const SizedBox(height: 10),
              const AppText('No Active Trip',
                  style: AppTextStyle.headlineSmall, fontWeight: FontWeight.w700),
              const SizedBox(height: 6),
              const AppText(
                'Abhi koi trip chalu nahi hai. Assigned trips dekh kar journey shuru karein.',
                style: AppTextStyle.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'View My Trips',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => homeController.changeTabIndex(1),
              ),
            ],
          ),
        );
      }

      final tripMap = {
        'currentMilestone': trip.currentMilestone,
        'status': trip.status,
        'milestonesLog': trip.milestonesLog,
        'pickupLocation': trip.pickupLocation,
        'dropLocation': trip.dropLocation,
        'dropCity': trip.dropCity,
      };
      final eta = trip.estimatedTime.isNotEmpty ? trip.estimatedTime : 'Pending';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppText('ACTIVE TRIP',
                      style: AppTextStyle.labelMedium,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: AppText('ETA $eta',
                      style: AppTextStyle.labelMedium,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('FROM', style: AppTextStyle.labelMedium),
                      AppText(trip.pickupCity,
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
                      AppText(trip.dropCity,
                          style: AppTextStyle.titleLarge,
                          fontWeight: FontWeight.w700,
                          textAlign: TextAlign.end),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TripProgressTracker(trip: tripMap, showSummary: false),
            const SizedBox(height: 18),
            AppButton(
              text: 'Resume Navigation',
              icon: Icons.navigation_rounded,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pushNamed(
                  Routes.TRIP_DETAILS,
                  arguments: {'tripId': trip.id, 'isAlreadyActive': true},
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildQuickActions(BuildContext context, HomeController home) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.72,
      children: [
        QuickActionTile(
          icon: Icons.local_shipping_rounded,
          label: 'My Trips',
          color: AppColors.primary,
          onTap: () => home.changeTabIndex(1),
        ),
        QuickActionTile(
          icon: Icons.receipt_long_rounded,
          label: 'Kharcha',
          color: AppColors.tertiaryDark,
          onTap: () => home.changeTabIndex(2),
        ),
        QuickActionTile(
          icon: Icons.description_rounded,
          label: 'Documents',
          color: AppColors.info,
          onTap: () => home.changeTabIndex(3),
        ),
        QuickActionTile(
          icon: Icons.sos_rounded,
          label: 'SOS',
          color: AppColors.error,
          onTap: controller.triggerEmergencySos,
        ),
      ],
    );
  }

  Widget _buildNotifications() {
    final notifs = Get.find<NotificationsController>();
    return Obx(() {
      final items = notifs.items.take(4).toList();
      if (items.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(Get.context!),
          child: const Row(
            children: [
              Icon(Icons.notifications_none_rounded,
                  color: AppColors.textHint, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: AppText('No notifications yet',
                    style: AppTextStyle.bodyMedium),
              ),
            ],
          ),
        );
      }
      return Column(
        children: items.map((n) {
          final read = n['read'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(Get.context!),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(n['title']?.toString() ?? '',
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.w700),
                      const SizedBox(height: 2),
                      AppText(n['body']?.toString() ?? '',
                          style: AppTextStyle.bodyMedium),
                    ],
                  ),
                ),
                if (!read)
                  Container(
                    margin: const EdgeInsets.only(left: 6, top: 4),
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1F1B18) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border:
          Border.all(color: isDark ? const Color(0xFF332E2A) : AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.charcoal.withValues(alpha: isDark ? 0.25 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
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
              gradient: const LinearGradient(colors: AppColors.charcoalGradient),
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
