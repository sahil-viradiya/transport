import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/widgets/trip_progress_tracker.dart';
import 'package:transport/widgets/notification_bell.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import '../controllers/admin_home_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/notifications_controller.dart';

class AdminHomeView extends GetView<AdminHomeController> {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Responsive: phones get a bottom nav + full-width content; web/desktop get
    // a left navigation rail and centred content so cards don't stretch.
    final isWide = MediaQuery.of(context).size.width >= 900;

    final List<Widget> pages = [
      _buildAnalyticsTab(context, isDark),
      _buildTripsTab(context, isDark),
      _buildTrucksTab(context, isDark),
      _buildUsersTab(context, isDark),
    ];

    Widget content = Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      final stack = IndexedStack(
        index: controller.currentTabIndex.value,
        children: pages,
      );
      if (!isWide) return stack;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: stack,
        ),
      );
    });

    if (isWide) {
      // Web/desktop: dark brand sidebar + top bar (reference dashboard layout).
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, isDark),
                const Divider(height: 1),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        controller.handleBackPress();
      },
      child: Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      // Wide layout draws its own top bar next to the sidebar.
      appBar: isWide
          ? null
          : AppBar(
              title: const AppText('Highway Terminal Admin',
                  style: AppTextStyle.headlineSmall,
                  fontWeight: FontWeight.bold),
              actions: [
                const NotificationBell(color: AppColors.textPrimary),
                IconButton(
                  icon:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  tooltip: 'Logout Session',
                  onPressed: controller.logout,
                ),
              ],
            ),
      body: content,
      bottomNavigationBar: isWide
          ? null
          : Obx(() => NavigationBar(
                selectedIndex: controller.currentTabIndex.value,
                onDestinationSelected: controller.changeTabIndex,
                backgroundColor:
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                indicatorColor: AppColors.primaryLight,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.analytics_outlined),
                    selectedIcon:
                        Icon(Icons.analytics_rounded, color: AppColors.primary),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.alt_route_outlined),
                    selectedIcon:
                        Icon(Icons.alt_route_rounded, color: AppColors.primary),
                    label: 'Trips',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping_rounded,
                        color: AppColors.primary),
                    label: 'Trucks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline_rounded),
                    selectedIcon:
                        Icon(Icons.people_rounded, color: AppColors.primary),
                    label: 'Roles',
                  ),
                ],
              )),
      ),
    );
  }

  // ---- Web/desktop shell: dark brand sidebar + top bar ----

  static const _navItems = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.alt_route_rounded, 'Trips'),
    (Icons.local_shipping_rounded, 'Trucks'),
    (Icons.people_rounded, 'Drivers'),
  ];

  Widget _buildSidebar() {
    return Container(
      width: 230,
      color: AppColors.charcoal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('BHARAT',
                          style: AppTextStyle.bodyLarge,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                      AppText('TRANSPORT',
                          style: AppTextStyle.labelMedium,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_navItems.length, (i) {
            final (icon, label) = _navItems[i];
            return Obx(() {
              final selected = controller.currentTabIndex.value == i;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => controller.changeTabIndex(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(icon,
                              size: 20,
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppText(label,
                                style: AppTextStyle.bodyMedium,
                                color:
                                    selected ? Colors.white : Colors.white70,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            });
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: controller.logout,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Obx(() {
            final (_, label) = _navItems[controller.currentTabIndex.value];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label,
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.w700),
                const AppText('Welcome Admin', style: AppTextStyle.labelMedium),
              ],
            );
          }),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showTripFormDialog(context, isDark),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Assign Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBell(color: AppColors.textSecondary),
        ],
      ),
    );
  }

  // ---- Dashboard: stats grid ----
  Widget _buildStatsGrid(bool isDark) {
    final stats = [
      ('TOTAL TRUCKS', '${controller.trucks.length}',
          Icons.local_shipping_rounded, const Color(0xFFDCFCE7),
          const Color(0xFF15803D), () => controller.changeTabIndex(2)),
      ('ASSIGNED TODAY', '${controller.assignedTrucks.length}',
          Icons.event_available_rounded, const Color(0xFFE0F2FE),
          const Color(0xFF0369A1), () => controller.changeTabIndex(2)),
      ('IDLE TRUCKS', '${controller.idleTrucks.length}',
          Icons.pause_circle_rounded, const Color(0xFFFEF9C3),
          const Color(0xFFA16207), () => controller.changeTabIndex(2)),
      ('BREAKDOWN', '${controller.problemTrucks.length}', Icons.build_rounded,
          const Color(0xFFFEE2E2), const Color(0xFFB91C1C),
          () => controller.changeTabIndex(2)),
      ('ACTIVE TRIPS', '${controller.activeTripsCount}',
          Icons.my_location_rounded, const Color(0xFFF3E8FF),
          const Color(0xFF7E22CE), controller.openActiveDrivers),
      ('COMPLETED', '${controller.completedTripsCount}', Icons.task_alt_rounded,
          const Color(0xFFE3FCEF), const Color(0xFF006644),
          () => controller.changeTabIndex(1)),
    ];
    return LayoutBuilder(builder: (context, cons) {
      final cols = cons.maxWidth >= 1100 ? 6 : (cons.maxWidth >= 700 ? 3 : 2);
      final w = (cons.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats
            .map((s) => SizedBox(
                  width: w,
                  child: _buildStatCard(s.$1, s.$2, s.$3, s.$4, s.$5, isDark,
                      onTap: s.$6),
                ))
            .toList(),
      );
    });
  }

  // ---- Dashboard: truck kanban (Assigned / Breakdown / Idle) ----
  Widget _buildTruckKanban(BuildContext context, bool isDark) {
    Widget assigned = _kanbanColumn(
      isDark,
      'Assigned Trucks',
      controller.assignedTrucks.length,
      AppColors.success,
      controller.assignedTrucks
          .take(4)
          .map((t) => _assignedTruckCard(context, isDark, t))
          .toList(),
      emptyText: 'Abhi koi truck assigned nahi hai.',
    );
    Widget breakdown = _kanbanColumn(
      isDark,
      'Breakdown Trucks',
      controller.problemTrucks.length,
      AppColors.error,
      controller.problemTrucks
          .take(4)
          .map((t) => _problemTruckCard(isDark, t))
          .toList(),
      emptyText: 'Koi breakdown nahi — sab theek! 🎉',
    );
    Widget idle = _kanbanColumn(
      isDark,
      'Idle Trucks',
      controller.idleTrucks.length,
      AppColors.tertiaryDark,
      controller.idleTrucks
          .take(4)
          .map((t) => _idleTruckCard(context, isDark, t))
          .toList(),
      emptyText: 'Sab trucks assigned hain.',
    );

    return LayoutBuilder(builder: (c, cons) {
      if (cons.maxWidth >= 900) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: assigned),
            const SizedBox(width: 16),
            Expanded(child: breakdown),
            const SizedBox(width: 16),
            Expanded(child: idle),
          ],
        );
      }
      return Column(
        children: [
          assigned,
          const SizedBox(height: 16),
          breakdown,
          const SizedBox(height: 16),
          idle,
        ],
      );
    });
  }

  Widget _kanbanColumn(bool isDark, String title, int count, Color dot,
      List<Widget> cards,
      {required String emptyText}) {
    final more = count - cards.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: dot),
              const SizedBox(width: 6),
              Expanded(
                child: AppText('$title ($count)',
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: AppText(emptyText,
                  style: AppTextStyle.labelMedium,
                  textAlign: TextAlign.center),
            )
          else
            ...cards,
          if (more > 0)
            TextButton(
              onPressed: () => controller.changeTabIndex(2),
              child: Text('+$more more'),
            ),
        ],
      ),
    );
  }

  BoxDecoration _kanbanCardDeco(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      );

  (String, Color) _assignedChip(Map<String, dynamic>? trip, String inspection) {
    switch (trip?['status']) {
      case 'EN_ROUTE_VENDOR':
        return ('On The Way', AppColors.info);
      case 'LOADING':
        return ('Loading', AppColors.tertiaryDark);
      case 'LOAD_REQUESTED':
        return ('Load Requested', AppColors.tertiaryDark);
      case 'ACTIVE NOW':
        return ('Active', AppColors.success);
      case 'DELIVERY_REQUESTED':
        return ('Delivery Requested', AppColors.info);
      case 'PENDING':
        return ('Pending Accept', AppColors.textSecondary);
      case 'ASSIGNED':
        return ('Trip Assigned', AppColors.primary);
    }
    return inspection == 'ready'
        ? ('Ready', AppColors.success)
        : ('Inspection Pending', AppColors.tertiaryDark);
  }

  Widget _kvRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textHint),
          const SizedBox(width: 6),
          AppText('$label: ',
              style: AppTextStyle.labelMedium, fontWeight: FontWeight.w600),
          Expanded(
            child: AppText(value,
                style: AppTextStyle.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _assignedTruckCard(
      BuildContext context, bool isDark, Map<String, dynamic> truck) {
    final phone = (truck['assignedTo'] ?? '').toString();
    final trip = controller.currentTripForDriver(phone);
    final (chipLabel, chipColor) =
        _assignedChip(trip, (truck['inspectionStatus'] ?? '').toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _kanbanCardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText((truck['truckNo'] ?? '').toString(),
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AppText(chipLabel,
                    style: AppTextStyle.labelMedium,
                    color: chipColor,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppText('Driver: ${controller.driverNameFor(phone)}',
              style: AppTextStyle.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          _kvRow(Icons.place_rounded, 'Pickup',
              (trip?['pickupLocation'] ?? '').toString()),
          _kvRow(Icons.category_rounded, 'Material',
              (trip?['materialName'] ?? '').toString()),
          _kvRow(Icons.confirmation_number_rounded, 'Pass',
              (trip?['loadingPassId'] ?? '').toString()),
          _kvRow(Icons.workspace_premium_rounded, 'Royalty',
              (trip?['royaltyName'] ?? '').toString()),
          _kvRow(
              Icons.flag_rounded,
              'Destination',
              (trip?['dropCity'] ?? '').toString().isEmpty
                  ? '— (set pending)'
                  : (trip?['dropCity'] ?? '').toString()),
          if (trip != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _showTripDetailsDialog(context, isDark, trip),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text('View Details',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                if ((trip['dropCity'] ?? '').toString().isEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showSetDestinationDialog(trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Set Destination',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _problemTruckCard(bool isDark, Map<String, dynamic> truck) {
    final phone = (truck['assignedTo'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _kanbanCardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText((truck['truckNo'] ?? '').toString(),
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w700),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const AppText('Breakdown',
                    style: AppTextStyle.labelMedium,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (phone.isNotEmpty)
            AppText('Driver: ${controller.driverNameFor(phone)}',
                style: AppTextStyle.labelMedium),
          const SizedBox(height: 6),
          _kvRow(Icons.report_problem_rounded, 'Reason',
              (truck['inspectionIssue'] ?? '').toString()),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: () =>
                controller.markTruckActive((truck['truckNo'] ?? '').toString()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Mark Active', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _idleTruckCard(
      BuildContext context, bool isDark, Map<String, dynamic> truck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _kanbanCardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText((truck['truckNo'] ?? '').toString(),
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w700),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const AppText('Idle',
                    style: AppTextStyle.labelMedium,
                    color: AppColors.tertiaryDark,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppText((truck['model'] ?? '').toString(),
              style: AppTextStyle.labelMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _showAssignTruckDialog(context, truck),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: const BorderSide(color: AppColors.success),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Assign Truck', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---- Dashboard: recent activities (admin's live notification feed) ----
  Widget _buildRecentActivities(bool isDark) {
    if (!Get.isRegistered<NotificationsController>()) {
      return const SizedBox.shrink();
    }
    final notifs = Get.find<NotificationsController>();
    Color dotFor(String type) {
      if (type.contains('reject') || type.contains('issue')) {
        return AppColors.error;
      }
      if (type.contains('accept') ||
          type.contains('ready') ||
          type.contains('approved') ||
          type.contains('activated')) {
        return AppColors.success;
      }
      return AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('Recent Activities',
              style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w700),
          const SizedBox(height: 10),
          Obx(() {
            final items = notifs.items.take(6).toList();
            if (items.isEmpty) {
              return const AppText('No recent activity.',
                  style: AppTextStyle.labelMedium);
            }
            return Column(
              children: items.map((n) {
                final ts = n['createdAt'];
                String when = '';
                try {
                  if (ts is Timestamp) when = timeAgo(ts.toDate());
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle,
                            size: 8,
                            color: dotFor((n['type'] ?? '').toString())),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText((n['title'] ?? '').toString(),
                                style: AppTextStyle.bodyMedium,
                                fontWeight: FontWeight.w700,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            AppText((n['body'] ?? '').toString(),
                                style: AppTextStyle.labelMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (when.isNotEmpty)
                        AppText(when,
                            style: AppTextStyle.labelMedium,
                            color: AppColors.textHint),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // --- TAB 1: ANALYTICS & LIVE TRACKING ---
  Widget _buildAnalyticsTab(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stat cards (6-up on desktop, wraps on phone)
            Obx(() => _buildStatsGrid(isDark)),
            const SizedBox(height: 20),

            // Truck kanban: Assigned / Breakdown / Idle
            Obx(() => _buildTruckKanban(context, isDark)),
            const SizedBox(height: 20),

            // Recent activities feed
            _buildRecentActivities(isDark),
            const SizedBox(height: 24),

            // Live Tracking Panel Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: AppText('LIVE DRIVER TRACKING',
                      style: AppTextStyle.labelLarge,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                TextButton.icon(
                  onPressed: controller.loadData,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const AppText('Sync', style: AppTextStyle.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Active Drivers List
            Obx(() {
              final activeTrips =
                  controller.trips.where((t) => t['isActive'] == true).toList();
              if (activeTrips.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.location_off_rounded,
                            color: AppColors.textHint, size: 40),
                        SizedBox(height: 8),
                        AppText(
                            'No active driver terminals en route currently.',
                            style: AppTextStyle.bodyMedium),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeTrips.length,
                itemBuilder: (context, index) {
                  final trip = activeTrips[index];
                  final driverPhone = trip['driverPhone'] ?? 'Assigned Driver';
                  final driverName = controller.users.firstWhere(
                    (u) => u['phone'] == driverPhone,
                    orElse: () => {'name': 'Active Driver'},
                  )['name'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_circle_rounded,
                                    color: AppColors.primary, size: 24),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(driverName,
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold),
                                    AppText('Trip ID: ${trip['id']}',
                                        style: AppTextStyle.labelMedium),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0B3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const AppText('EN ROUTE',
                                  style: AppTextStyle.labelMedium,
                                  color: Color(0xFFBF2600),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_rounded,
                                color: AppColors.secondary, size: 16),
                            const SizedBox(width: 8),
                            AppText('Truck: ${trip['truckNo']}',
                                style: AppTextStyle.bodyMedium,
                                fontWeight: FontWeight.w600),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Milestone-based progress — "truck kaha pahucha" without
                        // relying on continuous live GPS.
                        TripProgressTracker(trip: trip),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.my_location_rounded,
                                color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppText(
                                trip['currentAddress']?.isNotEmpty == true
                                    ? trip['currentAddress']
                                    : 'Awaiting coordinates sync...',
                                style: AppTextStyle.bodyMedium,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            AppText(
                              'Remaining: ${trip['remainingDistance']?.isNotEmpty == true ? trip['remainingDistance'] : "Calculating..."} • ETA: ${trip['estimatedTime']?.isNotEmpty == true ? trip['estimatedTime'] : "N/A"}',
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showLiveLocationDialog(context, isDark, trip),
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            label: const AppText('Locate Truck',
                                style: AppTextStyle.labelLarge,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        Obx(() {
                          final tripId = trip['id'];
                          final tripExpenses = controller.expenses
                              .where((exp) => exp['tripId'] == tripId)
                              .toList();
                          if (tripExpenses.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 24),
                              const AppText('EXPENSE CLAIMS',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold),
                              const SizedBox(height: 8),
                              ...tripExpenses.map((exp) {
                                final title = exp['title'] ?? 'Expense';
                                final amt = exp['amount'] ?? '₹0';
                                final desc = exp['description'] ?? '';
                                final status = exp['status'] ?? 'Pending';
                                final receiptUrl = exp['receiptUrl'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        title.contains('Fuel')
                                            ? Icons.local_gas_station_rounded
                                            : Icons.receipt_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AppText(title,
                                                style: AppTextStyle.bodyMedium,
                                                fontWeight: FontWeight.bold),
                                            if (desc.isNotEmpty)
                                              AppText(desc,
                                                  style:
                                                      AppTextStyle.labelMedium),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          AppText(amt,
                                              style: AppTextStyle.bodyMedium,
                                              fontWeight: FontWeight.bold),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'Approved'
                                                  ? Colors.green
                                                      .withValues(alpha: 0.1)
                                                  : Colors.orange
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: AppText(
                                              status,
                                              style: AppTextStyle.labelMedium,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'Approved'
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (receiptUrl.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.image_outlined,
                                              size: 20,
                                              color: AppColors.primary),
                                          tooltip: 'View Receipt',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogCtx) =>
                                                  AlertDialog(
                                                backgroundColor: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white,
                                                title: AppText(title,
                                                    style: AppTextStyle.headlineSmall,
                                                    fontWeight: FontWeight.bold),
                                                content: SizedBox(
                                                  width: 400,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        child: Image.network(
                                                          _getCorsWebUrl(receiptUrl),
                                                          height: 260,
                                                          width: double.infinity,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error,
                                                                  stackTrace) =>
                                                              const Icon(
                                                                  Icons
                                                                      .broken_image_outlined,
                                                                  size: 80),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      AppText('Amount: $amt',
                                                          style: AppTextStyle.bodyLarge,
                                                          fontWeight: FontWeight.bold),
                                                      if (desc.isNotEmpty) ...[
                                                        const SizedBox(height: 6),
                                                        AppText(desc,
                                                            style:
                                                                AppTextStyle.bodyMedium),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  if (status == 'Pending') ...[
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.green),
                                                      onPressed: () {
                                                        Navigator.of(dialogCtx).pop();
                                                        controller.approveExpense(exp);
                                                      },
                                                      child: const AppText('Approve',
                                                          style:
                                                              AppTextStyle.bodyMedium,
                                                          color: Colors.white),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(dialogCtx).pop();
                                                        controller.rejectExpense(exp);
                                                      },
                                                      child: const AppText('Reject',
                                                          style: AppTextStyle.bodyMedium,
                                                          color: AppColors.error),
                                                    ),
                                                  ],
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(dialogCtx).pop(),
                                                    child: const AppText('Close',
                                                        style: AppTextStyle.bodyMedium),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color bg,
      Color textCol, bool isDark,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : bg,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: AppText(label,
                        style: AppTextStyle.labelMedium,
                        color: isDark ? Colors.white70 : textCol,
                        fontWeight: FontWeight.bold)),
                Icon(icon,
                    color: isDark ? AppColors.primary : textCol, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            AppText(value,
                style: AppTextStyle.headlineLarge,
                color: isDark ? Colors.white : textCol,
                fontWeight: FontWeight.bold),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  AppText('View',
                      style: AppTextStyle.labelMedium,
                      color: isDark ? Colors.white54 : textCol,
                      fontWeight: FontWeight.w600),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: isDark ? Colors.white54 : textCol),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 2: TRIPS MANAGEMENT ---
  Widget _buildTripsTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          if (controller.trips.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.alt_route_rounded,
                          size: 60, color: AppColors.textHint),
                      SizedBox(height: 12),
                      AppText(
                          'No trips assigned yet. Tap "+" to assign a route.',
                          style: AppTextStyle.bodyLarge),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: controller.trips.length,
            itemBuilder: (context, index) {
              final trip = controller.trips[index];
              final isTripActive = trip['isActive'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTripActive
                                  ? const Color(0xFFFFF0B3)
                                  : (trip['status'] == 'DELIVERED'
                                      ? const Color(0xFFE3FCEF)
                                      : AppColors.primaryLight),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AppText(
                              trip['status'] ?? 'ASSIGNED',
                              style: AppTextStyle.labelMedium,
                              color: isTripActive
                                  ? const Color(0xFFBF2600)
                                  : (trip['status'] == 'DELIVERED'
                                      ? const Color(0xFF006644)
                                      : AppColors.primary),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.error, size: 20),
                            onPressed: () => controller.deleteTrip(trip['id']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText(trip['id'],
                              style: AppTextStyle.headlineSmall,
                              fontWeight: FontWeight.bold),
                          const SizedBox(width: 12),
                          Flexible(
                            child: AppText('Truck: ${trip['truckNo']}',
                                style: AppTextStyle.bodyMedium,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('Pickup',
                                    style: AppTextStyle.labelMedium),
                                AppText(trip['pickupCity'] ?? '',
                                    style: AppTextStyle.bodyLarge,
                                    fontWeight: FontWeight.bold),
                                AppText(trip['pickupLocation'] ?? '',
                                    style: AppTextStyle.labelMedium,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const AppText('Drop',
                                    style: AppTextStyle.labelMedium),
                                AppText(trip['dropCity'] ?? '',
                                    style: AppTextStyle.bodyLarge,
                                    fontWeight: FontWeight.bold),
                                AppText(trip['dropLocation'] ?? '',
                                    style: AppTextStyle.labelMedium,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // At-a-glance milestone progress for this trip.
                      TripProgressTracker(trip: trip, showSummary: false),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 14, color: AppColors.textHint),
                              const SizedBox(width: 6),
                              AppText(trip['date'] ?? '',
                                  style: AppTextStyle.labelMedium),
                            ],
                          ),
                          Row(
                            children: [
                              if ((trip['dropCity'] ?? '')
                                      .toString()
                                      .trim()
                                      .isEmpty &&
                                  trip['status'] != 'DELIVERED')
                                IconButton(
                                  icon: const Icon(
                                      Icons.add_location_alt_rounded,
                                      color: AppColors.tertiaryDark,
                                      size: 20),
                                  tooltip: 'Set Destination',
                                  onPressed: () =>
                                      _showSetDestinationDialog(trip),
                                ),
                              IconButton(
                                icon: const Icon(Icons.visibility_rounded,
                                    color: AppColors.primary, size: 20),
                                tooltip: 'View Audit Log & Details',
                                onPressed: () => _showTripDetailsDialog(
                                    context, isDark, trip),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: AppColors.primary, size: 20),
                                tooltip: 'Edit Trip',
                                onPressed: () => _showTripFormDialog(
                                    context, isDark,
                                    editModeTrip: trip),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: AppColors.primary,
        onPressed: () => _showTripFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 3: TRUCKS MANAGEMENT ---
  /// Morning duty allocation strip on each truck card: who it's assigned to,
  /// the driver's inspection verdict, and an Assign/Reassign action.
  Widget _truckAssignmentSection(
      BuildContext context, bool isDark, Map<String, dynamic> truck) {
    final assignedTo = (truck['assignedTo'] ?? '').toString();
    final inspection = (truck['inspectionStatus'] ?? '').toString();
    final issue = (truck['inspectionIssue'] ?? '').toString();

    String driverName = assignedTo;
    if (assignedTo.isNotEmpty) {
      final u = controller.users
          .firstWhereOrNull((u) => (u['phone'] ?? '') == assignedTo);
      if (u != null && (u['name'] ?? '').toString().isNotEmpty) {
        driverName = u['name'].toString();
      }
    }

    (String, Color, IconData) badge;
    if (assignedTo.isEmpty) {
      badge = ('Not Assigned', AppColors.textSecondary, Icons.person_off_rounded);
    } else if (inspection == 'ready') {
      badge = ('Ready ✓', AppColors.success, Icons.verified_rounded);
    } else if (inspection == 'problem') {
      badge = ('Problem Reported', AppColors.error, Icons.report_problem_rounded);
    } else {
      badge = ('Inspection Pending', AppColors.tertiaryDark, Icons.pending_rounded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(badge.$3, size: 16, color: badge.$2),
            const SizedBox(width: 6),
            Flexible(
              child: AppText(
                assignedTo.isEmpty
                    ? 'Not assigned to any driver'
                    : 'Driver: $driverName',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badge.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppText(badge.$1,
                  style: AppTextStyle.labelMedium,
                  color: badge.$2,
                  fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAssignTruckDialog(context, truck),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: Text(assignedTo.isEmpty ? 'Assign' : 'Reassign'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        if (inspection == 'problem' && issue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AppText('⚠️ $issue',
                style: AppTextStyle.labelMedium,
                color: AppColors.error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  void _showAssignTruckDialog(BuildContext context, Map<String, dynamic> truck) {
    final drivers = controller.users
        .where((u) => (u['role'] ?? 'driver') != 'admin')
        .toList();
    if (drivers.isEmpty) {
      AppSnackBar.showWarning(
          title: 'No Drivers', message: 'Pehle koi driver register karein.');
      return;
    }
    String selected = (truck['assignedTo'] ?? '').toString();
    if (selected.isEmpty ||
        !drivers.any((d) => (d['phone'] ?? '') == selected)) {
      selected = (drivers.first['phone'] ?? '').toString();
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Assign ${truck['truckNo']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Select Driver',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_rounded),
          ),
          items: drivers
              .map((d) => DropdownMenuItem(
                    value: (d['phone'] ?? '').toString(),
                    child: Text(
                      '${d['name'] ?? d['phone']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) selected = v;
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Get.back();
              controller.assignTruck(
                (truck['truckNo'] ?? '').toString(),
                selected,
                model: truck['model']?.toString(),
              );
            },
            child: const Text('Assign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrucksTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          if (controller.trucks.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 60, color: AppColors.textHint),
                      SizedBox(height: 12),
                      AppText('No trucks registered. Tap "+" to add a truck.',
                          style: AppTextStyle.bodyLarge),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: controller.trucks.length,
            itemBuilder: (context, index) {
              final truck = controller.trucks[index];
              final isEnRoute = truck['status'] == 'En Route';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.local_shipping_rounded,
                              color:
                                  isEnRoute ? Colors.green : AppColors.primary,
                              size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(truck['truckNo'] ?? '',
                                  style: AppTextStyle.bodyLarge,
                                  fontWeight: FontWeight.bold),
                              const SizedBox(height: 4),
                              AppText(truck['model'] ?? 'Tata Truck',
                                  style: AppTextStyle.labelMedium),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEnRoute
                                      ? const Color(0xFFE3FCEF)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: AppText(
                                  truck['status'] ?? 'Idle',
                                  style: AppTextStyle.labelMedium,
                                  color: isEnRoute
                                      ? const Color(0xFF006644)
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded,
                              color: AppColors.primary, size: 20),
                          onPressed: () => _showTruckFormDialog(context, isDark,
                              editModeTruck: truck),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                          onPressed: () =>
                              controller.deleteTruck(truck['truckNo']),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _truckAssignmentSection(context, isDark, truck),
                  ],
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: AppColors.primary,
        onPressed: () => _showTruckFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 4: ROLES & USERS MANAGEMENT ---
  Widget _availabilityBadge(Map<String, dynamic> user) {
    final available = (user['availability'] ?? 'off_duty') == 'available';
    final color = available ? AppColors.success : AppColors.textSecondary;
    final address = (user['checkInAddress'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(available ? Icons.circle : Icons.circle_outlined,
                  size: 9, color: color),
              const SizedBox(width: 5),
              AppText(available ? 'Available' : 'Off Duty',
                  style: AppTextStyle.labelMedium,
                  color: color,
                  fontWeight: FontWeight.bold),
            ],
          ),
        ),
        if (available && address.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 12, color: AppColors.error),
              const SizedBox(width: 3),
              Expanded(
                child: AppText(address,
                    style: AppTextStyle.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildUsersTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          if (controller.users.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 60, color: AppColors.textHint),
                      SizedBox(height: 12),
                      AppText('No users registered in terminal database.',
                          style: AppTextStyle.bodyLarge),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: controller.users.length,
            itemBuilder: (context, index) {
              final user = controller.users[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(user['avatarUrl'] ??
                          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(user['name'] ?? '',
                              style: AppTextStyle.bodyLarge,
                              fontWeight: FontWeight.bold),
                          const SizedBox(height: 2),
                          AppText(user['phone'] ?? '',
                              style: AppTextStyle.labelMedium),
                          if ((user['role'] ?? 'driver') != 'admin') ...[
                            const SizedBox(height: 6),
                            _availabilityBadge(user),
                          ],
                          const SizedBox(height: 4),
                          // Dropdown to toggle role in UI
                          Row(
                            children: [
                              const AppText('Role: ',
                                  style: AppTextStyle.labelMedium),
                              DropdownButton<String>(
                                value: user['role'] ?? 'driver',
                                elevation: 1,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'driver',
                                      child: AppText('Driver',
                                          style: AppTextStyle.labelMedium,
                                          fontWeight: FontWeight.bold)),
                                  DropdownMenuItem(
                                      value: 'admin',
                                      child: AppText('Admin',
                                          style: AppTextStyle.labelMedium,
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold)),
                                ],
                                onChanged: (value) {
                                  if (value != null && value != user['role']) {
                                    controller.editUserRole(
                                        user['phone'], value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                      onPressed: () => controller.deleteUser(user['phone']),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: AppColors.primary,
        onPressed: () => _showUserFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- POPUP DIALOG FORM HELPERS ---

  // 1. ADD / EDIT TRIP DIALOG

  /// Set the drop destination while the truck is loading — the driver sees it
  /// only after the load is approved.
  void _showSetDestinationDialog(Map<String, dynamic> trip) {
    final cityCtrl =
        TextEditingController(text: (trip['dropCity'] ?? '').toString());
    final locCtrl =
        TextEditingController(text: (trip['dropLocation'] ?? '').toString());
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set Destination — ${trip['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Drop City',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(
                labelText: 'Drop Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin_drop_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final city = cityCtrl.text.trim();
              final loc = locCtrl.text.trim();
              if (city.isEmpty || loc.isEmpty) {
                AppSnackBar.showWarning(
                    title: 'Incomplete',
                    message: 'Drop city aur location dono bharein.');
                return;
              }
              Get.back();
              controller.setDestination(
                  (trip['id'] ?? '').toString(), city, loc);
            },
            child: const Text('Set', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTripFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editModeTrip}) {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: editModeTrip?['id'] ?? '');
    final pickupCityCtrl =
        TextEditingController(text: editModeTrip?['pickupCity'] ?? '');
    final pickupLocCtrl =
        TextEditingController(text: editModeTrip?['pickupLocation'] ?? '');
    final dropCityCtrl =
        TextEditingController(text: editModeTrip?['dropCity'] ?? '');
    final dropLocCtrl =
        TextEditingController(text: editModeTrip?['dropLocation'] ?? '');
    final dateCtrl = TextEditingController(text: editModeTrip?['date'] ?? '');
    // Vendor / material details
    final vendorNameCtrl =
        TextEditingController(text: editModeTrip?['vendorName'] ?? '');
    final vendorLocCtrl =
        TextEditingController(text: editModeTrip?['vendorLocation'] ?? '');
    final materialCtrl =
        TextEditingController(text: editModeTrip?['materialName'] ?? '');
    final passHolderCtrl =
        TextEditingController(text: editModeTrip?['passHolderName'] ?? '');
    final royaltyCtrl =
        TextEditingController(text: editModeTrip?['royaltyName'] ?? '');
    final loadingPassCtrl =
        TextEditingController(text: editModeTrip?['loadingPassId'] ?? '');
    final pickupDistrictCtrl =
        TextEditingController(text: editModeTrip?['pickupDistrict'] ?? '');
    final pickupLatCtrl = TextEditingController(
        text: editModeTrip?['pickupLatitude'] != null
            ? editModeTrip!['pickupLatitude'].toString()
            : '18.9482');
    final pickupLngCtrl = TextEditingController(
        text: editModeTrip?['pickupLongitude'] != null
            ? editModeTrip!['pickupLongitude'].toString()
            : '72.9469');
    final dropLatCtrl = TextEditingController(
        text: editModeTrip?['dropLatitude'] != null
            ? editModeTrip!['dropLatitude'].toString()
            : '21.0792');
    final dropLngCtrl = TextEditingController(
        text: editModeTrip?['dropLongitude'] != null
            ? editModeTrip!['dropLongitude'].toString()
            : '79.0274');

    final availableTrucks =
        controller.trucks.map((t) => t['truckNo'] as String).toList();
    if (availableTrucks.isEmpty) availableTrucks.add('MH-12-BV-0045');
    String selectedTruck = editModeTrip?['truckNo'] ?? availableTrucks.first;
    if (!availableTrucks.contains(selectedTruck)) {
      availableTrucks.add(selectedTruck);
    }

    final availableDrivers = controller.users
        .where((u) => u['role'] == 'driver')
        .map((u) => u['phone'] as String)
        .toList();
    if (availableDrivers.isEmpty) availableDrivers.add('+919876543210');
    String selectedDriver =
        editModeTrip?['driverPhone'] ?? availableDrivers.first;
    if (!availableDrivers.contains(selectedDriver)) {
      availableDrivers.add(selectedDriver);
    }

    final availableTabs = ['Today', 'Upcoming', 'Active', 'Past'];
    String selectedTabType = editModeTrip?['tabType'] ?? 'Today';
    bool priority = editModeTrip?['priority'] ?? false;
    if (!availableTabs.contains(selectedTabType)) {
      selectedTabType = 'Today';
    }

    String formatDateTime(DateTime date, TimeOfDay time) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final monthStr = months[date.month - 1];
      final day = date.day;

      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';

      return "$day $monthStr, ${hour.toString().padLeft(2, '0')}:$minute $period";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(bottomSheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText(
                    editModeTrip != null ? 'Edit Trip' : 'Create New Trip',
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: idCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Trip ID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                          enabled: editModeTrip == null,
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedTruck,
                          decoration: const InputDecoration(
                            labelText: 'Assign Truck',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_shipping_rounded),
                          ),
                          items: availableTrucks
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) selectedTruck = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedDriver,
                          decoration: const InputDecoration(
                            labelText: 'Assign Driver',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          items: availableDrivers.map((d) {
                            final name = controller.users.firstWhere(
                                (u) => u['phone'] == d,
                                orElse: () => {'name': d})['name'];
                            return DropdownMenuItem(
                                value: d, child: Text('$name ($d)'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) selectedDriver = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedTabType,
                          decoration: const InputDecoration(
                            labelText: 'Tab Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: availableTabs
                              .map((tab) => DropdownMenuItem(
                                  value: tab, child: Text(tab)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) selectedTabType = val;
                          },
                        ),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (ctx, setSB) => SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.primary,
                            value: priority,
                            onChanged: (v) => setSB(() => priority = v),
                            secondary: const Icon(Icons.bolt_rounded,
                                color: AppColors.primary),
                            title: const AppText('Priority Trip',
                                style: AppTextStyle.bodyLarge,
                                fontWeight: FontWeight.w600),
                            subtitle: const AppText(
                                'Driver ko sabse upar "PRIORITY" tag ke saath dikhegi',
                                style: AppTextStyle.labelMedium),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- Vendor / Material details ---
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: vendorNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Vendor Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.storefront_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: vendorLocCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Vendor Location',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.place_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: materialCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Material Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.category_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pickupDistrictCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pickup District',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: passHolderCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pass Holder Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: royaltyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Royalty Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.workspace_premium_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: loadingPassCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          decoration: const InputDecoration(
                            labelText: 'Loading Pass ID (8 digits)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.confirmation_number_rounded),
                            counterText: '',
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Field required';
                            if (!RegExp(r'^\d{8}$').hasMatch(s)) {
                              return 'Exactly 8 digits required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: pickupCityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pickup City',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_city_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: dropCityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Drop City (optional)',
                                  helperText: 'Loading ke time set hoga',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_city_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: pickupLocCtrl,
                          decoration: InputDecoration(
                            labelText: 'Pickup Location',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.pin_drop_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded,
                                  color: AppColors.primary),
                              tooltip: 'Search Coordinates',
                              onPressed: () async {
                                final query =
                                    "${pickupLocCtrl.text.trim()}, ${pickupCityCtrl.text.trim()}";
                                await _resolveCoordinates(context, query,
                                    pickupLatCtrl, pickupLngCtrl);
                              },
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: pickupLatCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pickup Latitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_rounded),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => v!.isEmpty
                                    ? 'Required'
                                    : (double.tryParse(v) == null
                                        ? 'Invalid number'
                                        : null),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pickupLngCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pickup Longitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_rounded),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => v!.isEmpty
                                    ? 'Required'
                                    : (double.tryParse(v) == null
                                        ? 'Invalid number'
                                        : null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dropLocCtrl,
                          decoration: InputDecoration(
                            labelText: 'Drop Location (optional)',
                            helperText:
                                'Destination loading ke time set kar sakte hain',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.pin_drop_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded,
                                  color: AppColors.primary),
                              tooltip: 'Search Coordinates',
                              onPressed: () async {
                                final query =
                                    "${dropLocCtrl.text.trim()}, ${dropCityCtrl.text.trim()}";
                                await _resolveCoordinates(
                                    context, query, dropLatCtrl, dropLngCtrl);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: dropLatCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Drop Latitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_rounded),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => v!.isEmpty
                                    ? 'Required'
                                    : (double.tryParse(v) == null
                                        ? 'Invalid number'
                                        : null),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: dropLngCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Drop Longitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map_rounded),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) => v!.isEmpty
                                    ? 'Required'
                                    : (double.tryParse(v) == null
                                        ? 'Invalid number'
                                        : null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dateCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          onTap: () async {
                            final initialDate = DateTime.now();
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (selectedDate != null) {
                              final selectedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (selectedTime != null) {
                                dateCtrl.text =
                                    formatDateTime(selectedDate, selectedTime);
                              }
                            }
                          },
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(bottomSheetCtx).pop(),
                              child: const AppText('Cancel',
                                  style: AppTextStyle.bodyMedium),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final tripData = {
                                    'id': idCtrl.text.trim(),
                                    'truckNo': selectedTruck,
                                    'driverPhone': selectedDriver,
                                    'vendorName': vendorNameCtrl.text.trim(),
                                    'vendorLocation': vendorLocCtrl.text.trim(),
                                    'materialName': materialCtrl.text.trim(),
                                    'passHolderName': passHolderCtrl.text.trim(),
                                    'royaltyName': royaltyCtrl.text.trim(),
                                    'loadingPassId': loadingPassCtrl.text.trim(),
                                    'pickupDistrict':
                                        pickupDistrictCtrl.text.trim(),
                                    'pickupCity': pickupCityCtrl.text.trim(),
                                    'pickupLocation': pickupLocCtrl.text.trim(),
                                    'dropCity': dropCityCtrl.text.trim(),
                                    'dropLocation': dropLocCtrl.text.trim(),
                                    'date': dateCtrl.text.trim(),
                                    'tabType': selectedTabType,
                                    'priority': priority,
                                    'pickupLatitude': double.tryParse(
                                            pickupLatCtrl.text.trim()) ??
                                        18.9482,
                                    'pickupLongitude': double.tryParse(
                                            pickupLngCtrl.text.trim()) ??
                                        72.9469,
                                    'dropLatitude': double.tryParse(
                                            dropLatCtrl.text.trim()) ??
                                        21.0792,
                                    'dropLongitude': double.tryParse(
                                            dropLngCtrl.text.trim()) ??
                                        79.0274,
                                    'status':
                                        editModeTrip?['status'] ?? 'ASSIGNED',
                                    'isActive':
                                        editModeTrip?['isActive'] ?? false,
                                    'currentMilestone':
                                        editModeTrip?['currentMilestone'] ?? 0,
                                    'remainingDistance':
                                        editModeTrip?['remainingDistance'] ??
                                            '',
                                    'estimatedTime':
                                        editModeTrip?['estimatedTime'] ?? '',
                                    'currentAddress':
                                        editModeTrip?['currentAddress'] ?? '',
                                  };

                                  Navigator.of(bottomSheetCtx).pop();
                                  if (editModeTrip != null) {
                                    controller.editTrip(
                                        idCtrl.text.trim(), tripData);
                                  } else {
                                    controller.createTrip(tripData);
                                  }
                                }
                              },
                              child: const AppText('Save',
                                  style: AppTextStyle.bodyMedium,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. ADD / EDIT TRUCK DIALOG
  void _showTruckFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editModeTruck}) {
    final formKey = GlobalKey<FormState>();
    final noCtrl = TextEditingController(text: editModeTruck?['truckNo'] ?? '');
    final modelCtrl =
        TextEditingController(text: editModeTruck?['model'] ?? '');
    String status = editModeTruck?['status'] ?? 'Idle';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: AppText(editModeTruck != null ? 'Edit Truck' : 'Register Truck',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: noCtrl,
                decoration:
                    const InputDecoration(labelText: 'Truck Plate Number'),
                enabled: editModeTruck == null,
                validator: (v) => v!.isEmpty ? 'Field required' : null,
              ),
              TextFormField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'Truck Model'),
                validator: (v) => v!.isEmpty ? 'Field required' : null,
              ),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Idle', child: Text('Idle')),
                  DropdownMenuItem(value: 'En Route', child: Text('En Route')),
                ],
                onChanged: (val) {
                  if (val != null) status = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const AppText('Cancel', style: AppTextStyle.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final truckData = {
                  'truckNo': noCtrl.text.trim(),
                  'model': modelCtrl.text.trim(),
                  'status': status,
                };

                Navigator.of(dialogCtx).pop();
                if (editModeTruck != null) {
                  controller.editTruck(noCtrl.text.trim(), truckData);
                } else {
                  controller.createTruck(truckData);
                }
              }
            },
            child: const AppText('Save',
                style: AppTextStyle.bodyMedium, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // 3. ADD USER DIALOG
  void _showUserFormDialog(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+91');
    final avatarCtrl = TextEditingController(
        text:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop');
    String role = 'driver';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(bottomSheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const AppText(
                'Add User Profile',
                style: AppTextStyle.headlineSmall,
                fontWeight: FontWeight.bold,
              ),
              const Divider(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'User Full Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (+91...)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              !v!.startsWith('+91') || v.length < 13
                                  ? 'Format must be +91XXXXXXXXXX'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Assign Role',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.admin_panel_settings_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'driver', child: Text('Driver')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (val) {
                            if (val != null) role = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: avatarCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Avatar Image URL',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.image_rounded),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(bottomSheetCtx).pop(),
                              child: const AppText('Cancel',
                                  style: AppTextStyle.bodyMedium),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final userData = {
                                    'name': nameCtrl.text.trim(),
                                    'phone': phoneCtrl.text
                                        .trim()
                                        .replaceAll(' ', ''),
                                    'role': role,
                                    'avatarUrl': avatarCtrl.text.trim(),
                                  };

                                  Navigator.of(bottomSheetCtx).pop();
                                  controller.createUser(userData);
                                }
                              },
                              child: const AppText('Save',
                                  style: AppTextStyle.bodyMedium,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolveCoordinates(
    BuildContext context,
    String query,
    TextEditingController latCtrl,
    TextEditingController lngCtrl,
  ) async {
    if (query.trim().isEmpty || query.trim() == ",") {
      AppSnackBar.showError(
        title: 'Empty Query',
        message: 'Please enter location and city names first.',
      );
      return;
    }

    AppPopup.showLoading(message: 'Searching coordinates for "$query"...');
    bool resolved = false;

    // 1. Try native geocoding package (only on non-web platforms)
    if (!kIsWeb) {
      try {
        final locations = await locationFromAddress(query).timeout(
          const Duration(seconds: 4),
        );
        if (locations.isNotEmpty) {
          final loc = locations.first;
          latCtrl.text = loc.latitude.toStringAsFixed(6);
          lngCtrl.text = loc.longitude.toStringAsFixed(6);
          resolved = true;
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
            title: 'Location Resolved',
            message:
                'Found coordinates: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
          );
          return;
        }
      } catch (_) {
        // Fallback to web search
      }
    }

    // 2. Try Nominatim (OpenStreetMap) Web API Search via Dio
    if (!resolved) {
      try {
        final dio = Dio();
        dio.options.headers['User-Agent'] = 'TransportTerminalApp/1.0';

        // Step A: Search for full query
        var response = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': query,
            'format': 'json',
            'limit': 1,
          },
        ).timeout(const Duration(seconds: 5));

        List results = [];
        if (response.statusCode == 200 && response.data is List) {
          results = response.data as List;
        }

        // Step B: Fallback to searching only city if full query returned empty
        if (results.isEmpty && query.contains(',')) {
          final cityPart = query.split(',').last.trim();
          if (cityPart.isNotEmpty) {
            response = await dio.get(
              'https://nominatim.openstreetmap.org/search',
              queryParameters: {
                'q': cityPart,
                'format': 'json',
                'limit': 1,
              },
            ).timeout(const Duration(seconds: 5));
            if (response.statusCode == 200 && response.data is List) {
              results = response.data as List;
            }
          }
        }

        if (results.isNotEmpty) {
          final firstResult = results[0];
          final lat = double.tryParse(firstResult['lat'].toString());
          final lon = double.tryParse(firstResult['lon'].toString());
          if (lat != null && lon != null) {
            latCtrl.text = lat.toStringAsFixed(6);
            lngCtrl.text = lon.toStringAsFixed(6);
            resolved = true;
            AppPopup.hideLoading();
            AppSnackBar.showSuccess(
              title: 'Location Resolved (Web)',
              message:
                  'Found coordinates: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
            );
            return;
          }
        }
      } catch (_) {
        // Fallback to offline mock database
      }
    }

    // 3. Fallback to mock coordinates matching common transport cities
    final mockDB = {
      'mumbai': [18.9482, 72.9469],
      'jnpt': [18.9482, 72.9469],
      'nagpur': [21.0792, 79.0274],
      'mihan': [21.0792, 79.0274],
      'pune': [18.5204, 73.8567],
      'chakan': [18.7892, 73.8567],
      'nashik': [19.9975, 73.7898],
      'ahmedabad': [23.0225, 72.5714],
      'indore': [22.6208, 75.8039],
      'pithampur': [22.6208, 75.8039],
      'delhi': [28.7041, 77.1025],
      'bangalore': [12.9716, 77.5946],
      'chennai': [13.0827, 80.2707],
      'kolkata': [22.5726, 88.3639],
      'hyderabad': [17.3850, 78.4867],
      'gondal': [21.9622, 70.7968],
      'gonda': [21.9622, 70.7968],
      'rajkot': [22.3039, 70.8022],
      'iscon': [22.3039, 70.8022],
    };

    double? resolvedLat;
    double? resolvedLng;
    final cleanQuery = query.toLowerCase();

    mockDB.forEach((key, value) {
      if (cleanQuery.contains(key)) {
        resolvedLat = value[0];
        resolvedLng = value[1];
      }
    });

    AppPopup.hideLoading();

    if (resolvedLat != null && resolvedLng != null) {
      latCtrl.text = resolvedLat!.toStringAsFixed(6);
      lngCtrl.text = resolvedLng!.toStringAsFixed(6);
      AppSnackBar.showSuccess(
        title: 'Location Resolved (Offline)',
        message:
            'Found coordinates: ${resolvedLat!.toStringAsFixed(4)}, ${resolvedLng!.toStringAsFixed(4)}',
      );
    } else {
      AppSnackBar.showInfo(
        title: 'No Matches Found',
        message:
            'Could not automatically find coordinates. Please type them manually.',
      );
    }
  }

  // On-demand "where is my truck" — fetches the latest position the driver app
  // saved (every ~10 min while active) and shows the full address + coordinates
  // + how fresh it is. Not a live feed; refreshed only when the admin asks.
  Future<void> _showLiveLocationDialog(
      BuildContext context, bool isDark, Map<String, dynamic> trip) async {
    AppPopup.showLoading(message: 'Fetching latest location...');
    Map<String, dynamic>? data;
    try {
      data = await controller.fetchTripLocation(trip['id']);
    } catch (_) {}
    AppPopup.hideLoading();

    final lat = (data?['currentLatitude'] as num?)?.toDouble();
    final lng = (data?['currentLongitude'] as num?)?.toDouble();
    final address = (data?['currentAddress'] ?? '').toString();
    final tsRaw = data?['lastLocationUpdate'];
    final DateTime? updated = tsRaw is Timestamp ? tsRaw.toDate() : null;
    final hasLocation = lat != null && lng != null;
    final fresh = updated != null && isLocationFresh(updated);
    final mapsUrl = hasLocation
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : '';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('Truck ${trip['truckNo'] ?? ''}',
                            style: AppTextStyle.bodyLarge,
                            fontWeight: FontWeight.bold),
                        AppText('Trip ${trip['id']}',
                            style: AppTextStyle.labelMedium),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const Divider(height: 24),
              if (!hasLocation)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.location_off_rounded, color: AppColors.textHint),
                    SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        'No location saved yet. The driver app records its position every ~10 min while the trip is active. Ask the driver to open the active trip.',
                        style: AppTextStyle.bodyMedium,
                      ),
                    ),
                  ],
                )
              else ...[
                const AppText('LAST KNOWN LOCATION',
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHint),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                          address.isNotEmpty ? address : 'Address unavailable',
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded,
                        size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    AppText(
                        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                        style: AppTextStyle.bodyMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 16,
                        color: fresh ? AppColors.success : AppColors.warning),
                    const SizedBox(width: 8),
                    AppText(
                        updated != null
                            ? 'Updated ${timeAgo(updated)}'
                            : 'Update time unknown',
                        style: AppTextStyle.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: fresh ? AppColors.success : AppColors.warning),
                  ],
                ),
                if (!fresh && updated != null) ...[
                  const SizedBox(height: 4),
                  const AppText(
                      'This may be stale — the truck might have moved since.',
                      style: AppTextStyle.labelMedium,
                      color: AppColors.warning),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openInMaps(mapsUrl),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Open in Google Maps'),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: SelectableText(
                    mapsUrl,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                    _showLiveLocationDialog(context, isDark, trip);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInMaps(String url) async {
    if (url.isEmpty) return;
    try {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        AppSnackBar.showError(
            title: 'Could not open Maps',
            message: 'No map app found. Use the link shown below.');
      }
    } catch (_) {
      AppSnackBar.showError(
          title: 'Could not open Maps',
          message: 'Open the link shown below manually.');
    }
  }

  void _showTripDetailsDialog(
      BuildContext context, bool isDark, Map<String, dynamic> trip) {
    // 1. Resolve Driver Details
    final driverPhone = trip['driverPhone'] ?? 'N/A';
    final driverName = controller.users.firstWhere(
          (u) => u['phone'] == driverPhone,
          orElse: () => {'name': 'Assigned Driver'},
        )['name'] ??
        'Assigned Driver';

    // 2. Resolve Milestones Log
    final rawLogs = trip['milestonesLog'] as List?;
    final List<Map<String, dynamic>> logs = [];
    if (rawLogs != null && rawLogs.isNotEmpty) {
      for (var item in rawLogs) {
        if (item is Map) {
          logs.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      // Fallback: Generate mock history logs based on current status and coordinates
      final currentMilestone = trip['currentMilestone'] as int? ?? 0;
      final tripDate = trip['date'] ?? '24 Oct, 08:30 AM';

      logs.add({
        'milestone': 1,
        'label': 'Trip Assigned',
        'timestamp': tripDate,
        'address': trip['pickupLocation'] ?? 'JNPT Terminal',
        'latitude': trip['pickupLatitude'] ?? 18.9482,
        'longitude': trip['pickupLongitude'] ?? 72.9469,
      });

      if (currentMilestone >= 2) {
        logs.add({
          'milestone': 2,
          'label': 'Reached Pickup',
          'timestamp': '24 Oct, 09:45 AM',
          'address': trip['pickupLocation'] ?? 'JNPT Terminal',
          'latitude': trip['pickupLatitude'] ?? 18.9482,
          'longitude': trip['pickupLongitude'] ?? 72.9469,
        });
      }

      if (currentMilestone >= 3) {
        logs.add({
          'milestone': 3,
          'label': 'Loaded',
          'timestamp': '24 Oct, 11:30 AM',
          'address': trip['pickupLocation'] ?? 'JNPT Terminal',
          'latitude': trip['pickupLatitude'] ?? 18.9482,
          'longitude': trip['pickupLongitude'] ?? 72.9469,
        });
      }

      if (currentMilestone >= 4 || trip['status'] == 'DELIVERED') {
        logs.add({
          'milestone': 4,
          'label': 'Reached Drop / Delivered',
          'timestamp': '24 Oct, 09:15 PM',
          'address': trip['dropLocation'] ?? 'Mihan Hub',
          'latitude': trip['dropLatitude'] ?? 21.0792,
          'longitude': trip['dropLongitude'] ?? 79.0274,
        });
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrDesktop = screenWidth > 600;

    if (isWebOrDesktop) {
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Obx(() {
              final liveTrip = controller.trips.firstWhere(
                (t) => t['id'] == trip['id'],
                orElse: () => trip,
              );

              final isTripActive = liveTrip['isActive'] == true;
              final isDelivered = liveTrip['status'] == 'DELIVERED';

              final tripExpenses = controller.expenses
                  .where((exp) => exp['tripId'] == liveTrip['id'])
                  .toList();

              return Container(
                constraints: BoxConstraints(
                  maxWidth: 950,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppText(
                                    liveTrip['id'],
                                    style: AppTextStyle.headlineSmall,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTripActive
                                          ? const Color(0xFFFFF0B3)
                                          : (isDelivered
                                              ? const Color(0xFFE3FCEF)
                                              : AppColors.primaryLight),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: AppText(
                                      liveTrip['status'] ?? 'ASSIGNED',
                                      style: AppTextStyle.labelMedium,
                                      color: isTripActive
                                          ? const Color(0xFFBF2600)
                                          : (isDelivered
                                              ? const Color(0xFF006644)
                                              : AppColors.primary),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              AppText(
                                'Route: ${liveTrip['pickupCity']} ➔ ${liveTrip['dropCity']}',
                                style: AppTextStyle.bodyMedium,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Main Scrollable Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTripMetadataCard(
                                isDark, liveTrip, driverName, driverPhone),
                            const SizedBox(height: 20),
                            if (screenWidth > 900)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildMilestonesTimeline(
                                        dialogCtx, isDark, logs),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _buildTripExpensesPanel(
                                            dialogCtx, isDark, tripExpenses),
                                        if (isDelivered) ...[
                                          const SizedBox(height: 16),
                                          _buildPODDetailsPanel(
                                              dialogCtx, isDark, liveTrip),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildMilestonesTimeline(
                                  dialogCtx, isDark, logs),
                              const SizedBox(height: 16),
                              _buildTripExpensesPanel(
                                  dialogCtx, isDark, tripExpenses),
                              if (isDelivered) ...[
                                const SizedBox(height: 16),
                                _buildPODDetailsPanel(
                                    dialogCtx, isDark, liveTrip),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetCtx) {
          return Obx(() {
            final liveTrip = controller.trips.firstWhere(
              (t) => t['id'] == trip['id'],
              orElse: () => trip,
            );

            final isTripActive = liveTrip['isActive'] == true;
            final isDelivered = liveTrip['status'] == 'DELIVERED';

            final tripExpenses = controller.expenses
                .where((exp) => exp['tripId'] == liveTrip['id'])
                .toList();

            return Container(
              height: MediaQuery.of(bottomSheetCtx).size.height * 0.9,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AppText(
                                  liveTrip['id'],
                                  style: AppTextStyle.headlineSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTripActive
                                        ? const Color(0xFFFFF0B3)
                                        : (isDelivered
                                            ? const Color(0xFFE3FCEF)
                                            : AppColors.primaryLight),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: AppText(
                                    liveTrip['status'] ?? 'ASSIGNED',
                                    style: AppTextStyle.labelMedium,
                                    color: isTripActive
                                        ? const Color(0xFFBF2600)
                                        : (isDelivered
                                            ? const Color(0xFF006644)
                                            : AppColors.primary),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'Route: ${liveTrip['pickupCity']} ➔ ${liveTrip['dropCity']}',
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTripMetadataCard(
                              isDark, liveTrip, driverName, driverPhone),
                          const SizedBox(height: 20),
                          _buildMilestonesTimeline(context, isDark, logs),
                          const SizedBox(height: 20),
                          _buildTripExpensesPanel(
                              context, isDark, tripExpenses),
                          if (isDelivered) ...[
                            const SizedBox(height: 20),
                            _buildPODDetailsPanel(
                                context, isDark, liveTrip),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        },
      );
    }
  }

  // Helper: Trip metadata summary (Driver Name, phone, truck registration info)
  Widget _buildTripMetadataCard(bool isDark, Map<String, dynamic> trip,
      String driverName, String driverPhone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  radius: 22,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('DRIVER PROFILE',
                          style: AppTextStyle.labelMedium,
                          fontWeight: FontWeight.bold),
                      const SizedBox(height: 2),
                      AppText(driverName,
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.bold),
                      AppText(driverPhone, style: AppTextStyle.labelMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isDark ? Colors.white10 : Colors.grey.shade100,
                  radius: 22,
                  child: const Icon(Icons.local_shipping_rounded,
                      color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('VEHICLE ASSIGNED',
                          style: AppTextStyle.labelMedium,
                          fontWeight: FontWeight.bold),
                      const SizedBox(height: 2),
                      AppText(trip['truckNo'] ?? 'N/A',
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.bold),
                      AppText(
                        trip['currentAddress']?.isNotEmpty == true
                            ? 'GPS Tracking En Route'
                            : 'Sync Status: Awaiting GPS...',
                        style: AppTextStyle.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: High fidelity audit log vertical timeline
  Widget _buildMilestonesTimeline(
      BuildContext context, bool isDark, List<Map<String, dynamic>> logs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'JOURNEY MILESTONES AUDIT',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final label = log['label'] ?? 'Checkpoint';
              final timestamp = log['timestamp'] ?? '';
              final address = log['address'] ?? '';
              final lat = log['latitude'] ?? 0.0;
              final lng = log['longitude'] ?? 0.0;

              final isLast = index == logs.length - 1;
              // Stack-based timeline (no IntrinsicHeight) — avoids the 1px
              // sub-pixel overflow that IntrinsicHeight + wrapped text causes.
              return Stack(
                children: [
                  // Connector line drawn behind, from this dot's centre down to
                  // the next item's dot.
                  if (!isLast)
                    Positioned(
                      left: 11,
                      top: 12,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AppText(
                              '${index + 1}',
                              style: AppTextStyle.labelMedium,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppText(
                                        label,
                                        style: AppTextStyle.bodyMedium,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AppText(
                                      timestamp,
                                      style: AppTextStyle.labelMedium,
                                      color: AppColors.textHint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 14, color: Colors.redAccent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: AppText(
                                        address,
                                        style: AppTextStyle.labelMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                AppText(
                                  'GPS Coords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                  style: AppTextStyle.labelMedium,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper: Expenses listing with location, date/time and receipt photo preview
  Widget _buildTripExpensesPanel(BuildContext context, bool isDark,
      List<Map<String, dynamic>> expensesList) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              AppText(
                'TRIP EXPENSE CLAIMS',
                style: AppTextStyle.labelLarge,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const Divider(height: 24),
          if (expensesList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.currency_rupee_rounded,
                        size: 36, color: AppColors.textHint),
                    SizedBox(height: 8),
                    AppText('No expense claims recorded for this trip.',
                        style: AppTextStyle.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expensesList.length,
              itemBuilder: (context, index) {
                final exp = expensesList[index];
                final title = exp['title'] ?? 'Expense';
                final amt = exp['amount'] ?? '₹0';
                final desc = exp['description'] ?? '';
                final status = exp['status'] ?? 'Pending';
                final receiptUrl = exp['receiptUrl'] ?? '';
                final date = exp['date'] ?? '';
                final expAddress = exp['locationName'] ?? '';
                final expLat = exp['latitude'];
                final expLng = exp['longitude'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            title.contains('Fuel')
                                ? Icons.local_gas_station_rounded
                                : Icons.receipt_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              title,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(amt,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (desc.isNotEmpty)
                        AppText(desc, style: AppTextStyle.labelMedium),
                      const SizedBox(height: 4),
                      AppText('Logged on: $date',
                          style: AppTextStyle.labelMedium,
                          color: AppColors.textHint),

                      // Expense Location Log
                      if (expAddress.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.pin_drop_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(expAddress,
                                      style: AppTextStyle.labelMedium),
                                  if (expLat != null && expLng != null)
                                    AppText(
                                      'GPS: ${expLat.toStringAsFixed(5)}, ${expLng.toStringAsFixed(5)}',
                                      style: AppTextStyle.labelMedium,
                                      fontSize: 10,
                                      color: AppColors.textHint,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'Approved'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: AppText(
                              status,
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold,
                              color: status == 'Approved'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (receiptUrl.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.image_outlined,
                                      size: 16),
                                  label: const AppText('View Receipt',
                                      style: AppTextStyle.labelMedium,
                                      color: AppColors.primary),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        title: AppText(title,
                                            style: AppTextStyle.headlineSmall,
                                            fontWeight: FontWeight.bold),
                                        content: SizedBox(
                                          width: 400,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  _getCorsWebUrl(receiptUrl),
                                                  height: 260,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      const Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          size: 80),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              AppText('Amount: $amt',
                                                  style: AppTextStyle.bodyLarge,
                                                  fontWeight: FontWeight.bold),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                AppText(desc,
                                                    style:
                                                        AppTextStyle.bodyMedium),
                                              ],
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          if (status == 'Pending') ...[
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green),
                                              onPressed: () {
                                                Navigator.of(dialogCtx).pop();
                                                controller.approveExpense(exp);
                                              },
                                              child: const AppText('Approve',
                                                  style:
                                                      AppTextStyle.bodyMedium,
                                                  color: Colors.white),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(dialogCtx).pop();
                                                controller.rejectExpense(exp);
                                              },
                                              child: const AppText('Reject',
                                                  style: AppTextStyle.bodyMedium,
                                                  color: AppColors.error),
                                            ),
                                          ],
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dialogCtx).pop(),
                                            child: const AppText('Close',
                                                style: AppTextStyle.bodyMedium),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              if (status == 'Pending') ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () =>
                                      controller.approveExpense(exp),
                                  child: const AppText('Approve',
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => controller.rejectExpense(exp),
                                  child: const AppText('Reject',
                                      style: AppTextStyle.labelMedium,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Helper: Scanned Proof of Delivery (POD) details and remarks card
  Widget _buildPODDetailsPanel(
      BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final remarks = trip['remarks'] ?? 'No delivery comments left.';
    final podUrl = trip['podUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              AppText(
                'PROOF OF DELIVERY (POD)',
                style: AppTextStyle.labelLarge,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const Divider(height: 24),

          // Remarks Title
          const AppText('DRIVER REMARKS / NOTES',
              style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: AppText(
              remarks,
              style: AppTextStyle.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),

          // Scanned Document Image
          if (podUrl.isNotEmpty) ...[
            const AppText('SCANNED DOCUMENT PREVIEW',
                style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    _getCorsWebUrl(podUrl),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 220,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 48, color: AppColors.textHint),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 30),
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(),
                                  ),
                                ],
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _getCorsWebUrl(podUrl),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_outlined,
                                          size: 80, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                        'POD scanned document is missing or not uploaded.',
                        style: AppTextStyle.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getCorsWebUrl(String url) {
    if (kIsWeb && url.startsWith('http')) {
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
