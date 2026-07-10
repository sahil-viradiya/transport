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
import 'package:transport/widgets/trip_status_timeline.dart';
import 'package:transport/widgets/notification_bell.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import '../controllers/admin_home_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/notifications_controller.dart';
import 'admin_trip_details_view.dart';

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
                        Get.to(() => const AdminTripDetailsView(), arguments: {'tripId': trip['id']}),
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final body = (n['body'] ?? '').toString();
                      final match = RegExp(r'trip\s+(\w+)', caseSensitive: false).firstMatch(body);
                      final matchId = match?.group(1);
                      if (matchId != null) {
                        final trip = controller.trips.firstWhereOrNull((trip) => trip['id'].toString() == matchId);
                        if (trip != null) {
                          controller.selectedTripId.value = matchId;
                          AppSnackBar.showSuccess(
                            title: 'Trip Selected',
                            message: 'Switched dashboard tracker to trip $matchId',
                          );
                        }
                      }
                    },
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
  // --- TAB 1: ANALYTICS & GRID VIEW (DESKTOP DITTO MATCH) ---
  Widget _buildAnalyticsTab(BuildContext context, bool isDark) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    
    final layout = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1 & Column 2 (Left half)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTruckAssignmentsPanel(context, isDark)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTruckInspectionPendingPanel(context, isDark)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRecentNotificationsPanel(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 3: Current Trip Status
              Expanded(
                flex: 3,
                child: _buildCurrentTripStatusPanel(context, isDark),
              ),
              const SizedBox(width: 16),
              // Column 4: Quick Actions + Details + Contact
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildQuickActionsPanel(context, isDark),
                    const SizedBox(height: 16),
                    _buildTripDetailsPanel(isDark),
                    const SizedBox(height: 16),
                    _buildDriverContactPanel(isDark),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              _buildTruckAssignmentsPanel(context, isDark),
              const SizedBox(height: 16),
              _buildTruckInspectionPendingPanel(context, isDark),
              const SizedBox(height: 16),
              _buildCurrentTripStatusPanel(context, isDark),
              const SizedBox(height: 16),
              _buildRecentNotificationsPanel(isDark),
              const SizedBox(height: 16),
              _buildQuickActionsPanel(context, isDark),
              const SizedBox(height: 16),
              _buildTripDetailsPanel(isDark),
              const SizedBox(height: 16),
              _buildDriverContactPanel(isDark),
            ],
          );

    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWebStatsGrid(isDark),
            const SizedBox(height: 16),
            _buildWorkflowOverviewCard(isDark),
            const SizedBox(height: 16),
            layout,
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWebStatsGrid(bool isDark) {
    final stats = [
      ('Total Trucks', '${controller.trucks.length}', 'All Registered', Icons.local_shipping_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      ('Assigned Trucks', '${controller.assignedTrucks.length}', '100% Assigned', Icons.event_available_rounded, const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      ('Drivers', '${controller.users.where((u) => (u['role'] ?? 'driver') == 'driver').length}', 'All Active', Icons.people_rounded, const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
      ('Trips Today', '${controller.trips.length.toString().padLeft(2, '0')}', 'Total Trips', Icons.build_rounded, const Color(0xFFFFEDD5), const Color(0xFFEA580C)),
      ('Trips On Way', '${controller.trips.where((t) => t['status'] != 'DELIVERED' && t['status'] != 'REJECTED' && t['status'] != 'PENDING').length.toString().padLeft(2, '0')}', 'Currently On Way', Icons.explore_rounded, const Color(0xFFE0F2FE), const Color(0xFF2563EB)),
      ('Trips Completed', '${controller.completedTripsCount.toString().padLeft(2, '0')}', 'Today Completed', Icons.check_circle_rounded, const Color(0xFFE3FCEF), const Color(0xFF006644)),
    ];
    return LayoutBuilder(builder: (context, cons) {
      final cols = cons.maxWidth >= 1000 ? 6 : (cons.maxWidth >= 600 ? 3 : 2);
      final w = (cons.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats.map((s) {
          return SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(s.$1, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                        const SizedBox(height: 4),
                        AppText(s.$2, style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
                        const SizedBox(height: 2),
                        AppText(s.$3, style: AppTextStyle.labelMedium, color: AppColors.textHint),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: s.$5,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.$4, color: s.$6, size: 22),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildWorkflowOverviewCard(bool isDark) {
    const steps = [
      ('Assign Truck', 'Admin assigns truck to driver', Icons.local_shipping_rounded),
      ('Inspection', 'Driver inspects & submits', Icons.fact_check_rounded),
      ('Admin Review', 'Admin reviews inspection', Icons.rate_review_rounded),
      ('Accept Truck', 'Driver accepts truck', Icons.thumb_up_rounded),
      ('Assign Trip', 'Admin assigns trip', Icons.assignment_rounded),
      ('Accept Trip', 'Driver accepts trip', Icons.assignment_turned_in_rounded),
      ('On The Way', 'Driver on the way', Icons.local_shipping_rounded),
      ('Reached Vendor', 'Driver reached vendor', Icons.place_rounded),
      ('Loading', 'Truck is loading', Icons.inventory_2_rounded),
      ('On The Way (Dest.)', 'Admin sets destination', Icons.map_rounded),
      ('Trip Completed', 'Trip completed', Icons.task_alt_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Workflow Overview', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Container(
                    width: 24,
                    height: 2,
                    color: Colors.grey.shade300,
                  );
                }
                final idx = i ~/ 2;
                final step = steps[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(step.$3, color: AppColors.primary, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(step.$1, style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                          AppText(step.$2, style: AppTextStyle.labelMedium, color: AppColors.textHint),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckAssignmentsPanel(BuildContext context, bool isDark) {
    final assigned = controller.trucks.where((t) => (t['assignedTo'] ?? '').toString().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: AppText(
                  'Truck Assignments',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (controller.trucks.isNotEmpty) {
                    _showAssignTruckDialog(context, controller.trucks.first);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Assign Truck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(2.0),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Driver Name', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Truck Number', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, textAlign: TextAlign.center)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Status', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, textAlign: TextAlign.center)),
                ],
              ),
              ...assigned.take(5).map((t) {
                final driverPhone = t['assignedTo'].toString();
                final driverName = controller.driverNameFor(driverPhone);
                final driverTrip = controller.trips.firstWhereOrNull((trip) =>
                    trip['driverPhone'].toString() == driverPhone && trip['status'] != 'DELIVERED');

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                  ),
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (driverTrip != null) {
                          controller.selectedTripId.value = driverTrip['id'].toString();
                          AppSnackBar.showSuccess(
                            title: 'Trip Selected',
                            message: 'Selected active trip ${driverTrip['id']} for $driverName',
                          );
                        }
                      },
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppText(driverName, style: AppTextStyle.bodyMedium)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (driverTrip != null) {
                          controller.selectedTripId.value = driverTrip['id'].toString();
                          AppSnackBar.showSuccess(
                            title: 'Trip Selected',
                            message: 'Selected active trip ${driverTrip['id']} for $driverName',
                          );
                        }
                      },
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppText(t['truckNo'], style: AppTextStyle.bodyMedium, textAlign: TextAlign.center)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (driverTrip != null) {
                          controller.selectedTripId.value = driverTrip['id'].toString();
                          AppSnackBar.showSuccess(
                            title: 'Trip Selected',
                            message: 'Selected active trip ${driverTrip['id']} for $driverName',
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: AppText('Assigned', style: AppTextStyle.labelMedium, color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText('Total ${controller.users.where((u) => (u['role'] ?? 'driver') == 'driver').length} Drivers', style: AppTextStyle.labelMedium, color: AppColors.textHint),
              TextButton(
                onPressed: () => controller.changeTabIndex(2),
                child: const AppText('View All', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTruckInspectionPendingPanel(BuildContext context, bool isDark) {
    final pending = controller.trucks.where((t) => t['inspectionStatus'] == 'inspected_pending_review').toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Truck Inspection',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText('${pending.length} Pending', style: AppTextStyle.labelMedium, color: AppColors.warning, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 32),
                    SizedBox(height: 8),
                    AppText('No pending inspections', style: AppTextStyle.labelMedium),
                  ],
                ),
              ),
            )
          else
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(2.0),
                1: FlexColumnWidth(2.0),
                2: FlexColumnWidth(2.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                  ),
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Driver', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Truck No.', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Submitted On', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, textAlign: TextAlign.center)),
                  ],
                ),
                ...pending.take(5).map((t) {
                  final driverPhone = t['assignedTo'].toString();
                  final driverName = controller.driverNameFor(driverPhone);
                  final ts = t['inspectedAt'];
                  String dateStr = '—';
                  if (ts != null) {
                    try {
                      final dt = ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : DateTime.parse(ts.toString()));
                      dateStr = "${dt.day.toString().padLeft(2, '0')} ${[
                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                      ][dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
                    } catch (_) {}
                  }
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _showInspectionReviewDialog(context, isDark, t),
                          child: Text(driverName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppText(t['truckNo'], style: AppTextStyle.bodyMedium, textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppText(dateStr, style: AppTextStyle.bodyMedium, textAlign: TextAlign.center)),
                    ],
                  );
                }),
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => controller.changeTabIndex(2),
              child: const AppText('View All', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotificationsPanel(bool isDark) {
    if (!Get.isRegistered<NotificationsController>()) {
      return const SizedBox.shrink();
    }
    final notifs = Get.find<NotificationsController>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('Recent Notifications', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
          const SizedBox(height: 12),
          Obx(() {
            final items = notifs.items.take(5).toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: AppText('No recent notifications', style: AppTextStyle.labelMedium)),
              );
            }
            return Column(
              children: items.map((n) {
                final ts = n['createdAt'];
                String when = '';
                try {
                  if (ts is Timestamp) when = timeAgo(ts.toDate());
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(n['title']?.toString() ?? '', style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                            AppText(n['body']?.toString() ?? '', style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      if (when.isNotEmpty)
                        AppText(when, style: AppTextStyle.labelMedium, color: AppColors.textHint),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                if (Get.isRegistered<NotificationsController>()) {
                  const NotificationBell().open(Get.context!);
                }
              },
              child: const AppText('View All Notifications', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsOnWayPanel(BuildContext context, bool isDark) {
    final activeTrips = controller.trips.where((t) => t['status'] != 'DELIVERED' && t['status'] != 'REJECTED' && t['status'] != 'PENDING').toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: AppText(
                  'Trips On Way',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText('${activeTrips.length} On Way', style: AppTextStyle.labelMedium, color: AppColors.info, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: AppText('No active trips', style: AppTextStyle.labelMedium)),
            )
          else
            Obx(() => Column(
              children: activeTrips.take(4).map((t) {
                final isSelected = controller.selectedTripId.value == t['id'].toString();
                final isTripActive = t['isActive'] == true;
                return GestureDetector(
                  onTap: () {
                    controller.selectedTripId.value = t['id'].toString();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                        width: isSelected ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isTripActive
                                      ? const Color(0xFFFFF0B3)
                                      : (t['status'] == 'DELIVERED'
                                          ? const Color(0xFFE3FCEF)
                                          : AppColors.primaryLight),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: AppText(
                                  t['status'] ?? 'ASSIGNED',
                                  style: AppTextStyle.labelMedium,
                                  color: isTripActive
                                      ? const Color(0xFFBF2600)
                                      : (t['status'] == 'DELIVERED'
                                          ? const Color(0xFF006644)
                                          : AppColors.primary),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => controller.deleteTrip(t['id']),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(t['id'].toString(),
                                  style: AppTextStyle.headlineSmall,
                                  fontWeight: FontWeight.w800),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: AppText('Truck: ${t['truckNo']}',
                                      style: AppTextStyle.bodyMedium,
                                      fontWeight: FontWeight.bold,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AppText('Pickup', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                                    const SizedBox(height: 2),
                                    AppText(t['pickupCity'] ?? '',
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold),
                                    if ((t['pickupLocation'] ?? '').toString().trim().toLowerCase() !=
                                        (t['pickupCity'] ?? '').toString().trim().toLowerCase())
                                      AppText(t['pickupLocation'] ?? '',
                                          style: AppTextStyle.labelMedium,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: AppColors.primary.withOpacity(0.2), thickness: 1.5)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary.withOpacity(0.8), size: 16),
                                        ),
                                        Expanded(child: Divider(color: AppColors.primary.withOpacity(0.2), thickness: 1.5)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const AppText('Drop', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                                    const SizedBox(height: 2),
                                    AppText(t['dropCity'] ?? '',
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold),
                                    if ((t['dropLocation'] ?? '').toString().trim().toLowerCase() !=
                                        (t['dropCity'] ?? '').toString().trim().toLowerCase())
                                      AppText(t['dropLocation'] ?? '',
                                          style: AppTextStyle.labelMedium,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
                          Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ExpansionTile(
                                iconColor: AppColors.primary,
                                collapsedIconColor: AppColors.textSecondary,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                title: const AppText('Trip Status Timeline',
                                    style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                children: [
                                  TripStatusTimeline(
                                    tripId: t['id'].toString(),
                                    status: t['status'] ?? 'PENDING',
                                    driverName: t['driverName'] ?? '',
                                    truckNo: t['truckNo'] ?? '',
                                    dropCity: t['dropCity'] ?? '',
                                    milestonesLog: t['milestonesLog'] as List?,
                                    tripDate: (t['date'] ?? '').toString(),
                                    showHeader: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textHint),
                                  const SizedBox(width: 6),
                                  AppText(t['date'] ?? '', style: AppTextStyle.labelMedium),
                                ],
                              ),
                              Row(
                                children: [
                                  if ((t['dropCity'] ?? '').toString().trim().isEmpty && t['status'] != 'DELIVERED') ...[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.tertiary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.tertiaryDark, size: 16),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _showSetDestinationDialog(t),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.visibility_rounded, color: AppColors.primary, size: 16),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => Get.to(() => const AdminTripDetailsView(), arguments: {'tripId': t['id']}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 16),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showTripFormDialog(context, isDark, editModeTrip: t),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => controller.changeTabIndex(1),
              child: const AppText('View All Trips', style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTripStatusPanel(BuildContext context, bool isDark) {
    return Obx(() {
      final activeTrips = controller.trips.where((t) => t['status'] != 'DELIVERED').toList();
      var tripId = controller.selectedTripId.value;
      if (tripId.isEmpty && activeTrips.isNotEmpty) {
        tripId = activeTrips.first['id'].toString();
        Future.microtask(() => controller.selectedTripId.value = tripId);
      }
      final trip = controller.trips.firstWhereOrNull((t) => t['id'].toString() == tripId);
      if (trip == null) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
          ),
          child: const Center(child: AppText('Select a trip on way to track status.', style: AppTextStyle.labelMedium)),
        );
      }

      final status = trip['status'].toString();
      final done = _doneCount(status);
      final driverPhone = trip['driverPhone'].toString();
      final driverName = controller.driverNameFor(driverPhone);
      final truckNo = trip['truckNo'].toString();
      final dropCity = (trip['dropCity'] ?? '').toString();

      final loadingStarted = status == 'LOADING' || status == 'LOAD_REQUESTED';
      final isDestSet = dropCity.trim().isNotEmpty;
      
      // Calculate if no action taken for 10 minutes (mock or compute)
      bool showNoActionReminder = false;
      final ts = trip['loadingStartedAt'] ?? trip['loadRequestedAt'];
      if (loadingStarted && !isDestSet && ts != null) {
        try {
          final start = ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : DateTime.parse(ts.toString()));
          final diff = DateTime.now().difference(start);
          if (diff >= const Duration(minutes: 10)) {
            showNoActionReminder = true;
          }
        } catch (_) {}
      }

      final stages = [
        ('Trip Assigned', 'Trip assigned by admin', 08, 00, done >= 1),
        ('Trip Accepted', 'Driver accepted the trip', 08, 30, done >= 2),
        ('On The Way', 'Driver is on the way to vendor', 09, 15, done >= 3),
        ('Reached Vendor', 'Driver reached vendor location', 09, 45, done >= 4),
        ('Loading Started', 'Truck is loading at vendor', 10, 00, done >= 5),
        ('Loading Completed', 'Loading finished', 10, 30, done >= 6),
        ('Destination Set', isDestSet ? 'Destination: $dropCity' : 'Pending (Admin Action Required)', 10, 45, isDestSet),
        ('On The Way (Destination)', 'Truck traveling to destination', 11, 00, done >= 8),
        ('Trip Completed', 'Trip completed successfully', 11, 30, done >= 9),
      ];

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AppText('Current Trip Status - $tripId', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeTrips.length > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: tripId,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                    isExpanded: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: activeTrips.map((t) {
                      final tId = t['id'].toString();
                      final dPhone = t['driverPhone'].toString();
                      final dName = controller.driverNameFor(dPhone);
                      final trNo = t['truckNo'] ?? 'No Truck';
                      return DropdownMenuItem<String>(
                        value: tId,
                        child: AppText(
                          'Trip $tId - $dName ($trNo)',
                          style: AppTextStyle.bodyMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        controller.selectedTripId.value = newId;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppText('Driver: $driverName  •  Truck: $truckNo', style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
            const Divider(height: 24),
            Column(
              children: List.generate(stages.length, (i) {
                final stage = stages[i];
                final isCurrent = i == done && !stage.$5;
                final color = stage.$5 ? AppColors.success : (isCurrent ? AppColors.info : AppColors.textHint);
                
                String timeStr = '${stage.$3.toString().padLeft(2, '0')}:${stage.$4.toString().padLeft(2, '0')} AM';
                
                // Highlight LOADING STARTED in orange like mockup if active
                Color bulletColor = color;
                if (stage.$1 == 'Loading Started' && status == 'LOADING') {
                  bulletColor = AppColors.warning;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AppText(timeStr, style: AppTextStyle.labelMedium, color: AppColors.textHint),
                      ),
                    ),
                    Column(
                      children: [
                        Icon(
                          stage.$5
                              ? Icons.check_circle_rounded
                              : (isCurrent
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.circle_outlined),
                          size: 18,
                          color: bulletColor,
                        ),
                        if (i != stages.length - 1)
                          Container(
                            width: 2,
                            height: 32,
                            color: stage.$5 ? AppColors.success.withOpacity(0.4) : Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(stage.$1, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold, color: bulletColor),
                            AppText(stage.$2, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            if (loadingStarted && !isDestSet) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_rounded, color: AppColors.warning, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: AppText('Destination not set yet', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: AppColors.tertiaryDark)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const AppText('Please set destination location for this trip.', style: AppTextStyle.labelMedium, color: AppColors.tertiaryDark),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showSetDestinationDialog(trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Set Destination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (showNoActionReminder) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('No Action Reminder', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: AppColors.error),
                          AppText('No action taken for last 10 minutes. Please set destination location.', style: AppTextStyle.labelMedium, color: AppColors.error),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (loadingStarted && !isDestSet) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText('Contact Driver', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: AppColors.info),
                          AppText('Call $driverName to coordinate.', style: AppTextStyle.labelMedium, color: AppColors.info),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await launchUrl(Uri.parse('tel:$driverPhone'));
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.call, size: 14),
                      label: const Text('Call Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildQuickActionsPanel(BuildContext context, bool isDark) {
    Widget actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 85,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Flexible(
                  child: AppText(
                    label,
                    style: AppTextStyle.labelMedium,
                    color: color,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: AppText(
                  'Quick Actions',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  AppPopup.showLoading(message: 'Clearing Database...');
                  await controller.clearDatabase();
                  AppPopup.hideLoading();
                  AppSnackBar.showSuccess(title: 'Database Cleared', message: 'All testing data has been wiped.');
                },
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
                label: const Text('Reset Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              actionBtn(Icons.local_shipping_rounded, 'Add Truck', AppColors.primary, () => _showTruckFormDialog(context, isDark)),
              const SizedBox(width: 8),
              actionBtn(Icons.person_add_rounded, 'Assign Truck', AppColors.info, () {
                if (controller.trucks.isNotEmpty) {
                  _showAssignTruckDialog(context, controller.trucks.first);
                }
              }),
              const SizedBox(width: 8),
              actionBtn(Icons.person_add_alt_1_rounded, 'Add Driver', Colors.purple, () => _showUserFormDialog(context, isDark)),
              const SizedBox(width: 8),
              actionBtn(Icons.assignment_rounded, 'Assign Trip', AppColors.warning, () => _showTripFormDialog(context, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsPanel(bool isDark) {
    return Obx(() {
      final tripId = controller.selectedTripId.value;
      final trip = controller.trips.firstWhereOrNull((t) => t['id'] == tripId);
      if (trip == null) {
        return const SizedBox.shrink();
      }

      Widget row(String label, String val) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(label, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
              AppText(val.isEmpty ? '—' : val, style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            ],
          ),
        );
      }

      final driverName = controller.driverNameFor(trip['driverPhone'].toString());
      final status = trip['status'].toString();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText('Trip Details - $tripId', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            row('Vendor Name', trip['vendorName'].toString()),
            row('Vendor Location', trip['vendorLocation'].toString()),
            row('Material Name', trip['materialName'].toString()),
            row('Truck Number', trip['truckNo'].toString()),
            row('Driver Name', driverName),
            row('Pickup Location', trip['pickupLocation'].toString()),
            row('Pickup District', (trip['pickupDistrict'] ?? 'Navsari').toString()),
            row('Pass Holder Name', trip['passHolderName'].toString()),
            row('Royalty Name', trip['royaltyName'].toString()),
            row('Loading Pass ID', trip['loadingPassId'].toString()),
            row('Min Pass ID', (trip['minPassId'] ?? '10000000').toString()),
            row('Max Pass ID', (trip['maxPassId'] ?? '99999999').toString()),
            row('Status', _friendlyStatus(status)),
          ],
        ),
      );
    });
  }

  Widget _buildDriverContactPanel(bool isDark) {
    return Obx(() {
      final tripId = controller.selectedTripId.value;
      final trip = controller.trips.firstWhereOrNull((t) => t['id'] == tripId);
      if (trip == null) {
        return const SizedBox.shrink();
      }
      final driverPhone = trip['driverPhone'].toString();
      final driverName = controller.driverNameFor(driverPhone);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Driver Contact', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(driverName, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                      AppText(driverPhone, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await launchUrl(Uri.parse('tel:$driverPhone'));
                } catch (_) {}
              },
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Call Driver', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    });
  }

  static String _friendlyStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'ASSIGNED':
        return 'Trip Assigned';
      case 'EN_ROUTE_VENDOR':
        return 'On The Way to Vendor';
      case 'LOADING':
        return 'Loading started';
      case 'LOAD_REQUESTED':
        return 'Loaded (Pending Approval)';
      case 'ACTIVE NOW':
        return 'On The Way (Destination)';
      case 'DELIVERY_REQUESTED':
        return 'Reached Destination';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
    }
  }

  static int _doneCount(String status) {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'ASSIGNED':
        return 1;
      case 'EN_ROUTE_VENDOR':
        return 2;
      case 'LOADING':
        return 3;
      case 'LOAD_REQUESTED':
        return 4;
      case 'ACTIVE NOW':
        return 7;
      case 'DELIVERY_REQUESTED':
        return 8;
      case 'DELIVERED':
        return 9;
      default:
        return 0;
    }
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

  void _showInspectionReviewDialog(BuildContext context, bool isDark, Map<String, dynamic> truck) {
    final results = truck['inspectionResults'] as Map<dynamic, dynamic>? ?? {};
    final remarks = truck['inspectionRemarks']?.toString() ?? 'No remarks';
    final images = truck['inspectionImages'] as List<dynamic>? ?? [];
    final driverPhone = truck['assignedTo'].toString();
    final driverName = controller.driverNameFor(driverPhone);

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Review Inspection: ${truck['truckNo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('Driver: $driverName', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                const Divider(height: 16),
                const AppText('Checklist Results:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                const SizedBox(height: 6),
                ...results.entries.map((e) {
                  final isGood = e.value == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(isGood ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isGood ? AppColors.success : AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        AppText(e.key.toString(), style: AppTextStyle.bodyMedium),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                AppText('Remarks: $remarks', style: AppTextStyle.bodyMedium),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const AppText('Inspection Photos:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (ctx, i) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              images[i].toString(),
                              width: 240,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Get.back();
              controller.rejectInspection(truck['truckNo']);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Get.back();
              controller.approveInspection(truck['truckNo']);
            },
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isTripActive
                                  ? const Color(0xFFFFF0B3)
                                  : (trip['status'] == 'DELIVERED'
                                      ? const Color(0xFFE3FCEF)
                                      : AppColors.primaryLight),
                              borderRadius: BorderRadius.circular(8),
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
                                color: AppColors.error, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => controller.deleteTrip(trip['id']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText(trip['id'],
                              style: AppTextStyle.headlineSmall,
                              fontWeight: FontWeight.w800),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText('Truck: ${trip['truckNo']}',
                                  style: AppTextStyle.bodyMedium,
                                  fontWeight: FontWeight.bold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('Pickup',
                                    style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                                const SizedBox(height: 2),
                                AppText(trip['pickupCity'] ?? '',
                                    style: AppTextStyle.bodyLarge,
                                    fontWeight: FontWeight.bold),
                                if ((trip['pickupLocation'] ?? '').toString().trim().toLowerCase() !=
                                    (trip['pickupCity'] ?? '').toString().trim().toLowerCase())
                                  AppText(trip['pickupLocation'] ?? '',
                                      style: AppTextStyle.labelMedium,
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: AppColors.primary.withOpacity(0.2), thickness: 1.5)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary.withOpacity(0.8), size: 16),
                                        ),
                                    Expanded(child: Divider(color: AppColors.primary.withOpacity(0.2), thickness: 1.5)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const AppText('Drop',
                                    style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                                const SizedBox(height: 2),
                                AppText(trip['dropCity'] ?? '',
                                    style: AppTextStyle.bodyLarge,
                                    fontWeight: FontWeight.bold),
                                if ((trip['dropLocation'] ?? '').toString().trim().toLowerCase() !=
                                    (trip['dropCity'] ?? '').toString().trim().toLowerCase())
                                  AppText(trip['dropLocation'] ?? '',
                                      style: AppTextStyle.labelMedium,
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
                      // At-a-glance milestone progress for this trip.
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ExpansionTile(
                            iconColor: AppColors.primary,
                            collapsedIconColor: AppColors.textSecondary,
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: const AppText('Trip Status Timeline',
                                style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                            children: [
                              TripStatusTimeline(
                                tripId: trip['id'].toString(),
                                status: trip['status'] ?? 'PENDING',
                                driverName: trip['driverName'] ?? '',
                                truckNo: trip['truckNo'] ?? '',
                                dropCity: trip['dropCity'] ?? '',
                                milestonesLog: trip['milestonesLog'] as List?,
                                tripDate: (trip['date'] ?? '').toString(),
                                showHeader: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade100, thickness: 1),
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
                                  trip['status'] != 'DELIVERED') ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.tertiary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                        Icons.add_location_alt_rounded,
                                        color: AppColors.tertiaryDark,
                                        size: 16),
                                    onPressed: () =>
                                        _showSetDestinationDialog(trip),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.visibility_rounded,
                                      color: AppColors.primary, size: 16),
                                  onPressed: () => Get.to(() => const AdminTripDetailsView(), arguments: {'tripId': trip['id']}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppColors.primary, size: 16),
                                  onPressed: () => _showTripFormDialog(
                                      context, isDark,
                                      editModeTrip: trip),
                                ),
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

    final availableDrivers = controller.users.where((u) {
      if (u['role'] != 'driver') return false;
      final phone = u['phone'] as String?;
      if (phone == null || phone.isEmpty) return false;
      
      // Find the truck assigned to this driver phone
      final truck = controller.trucks.firstWhereOrNull((t) => t['assignedTo'] == phone);
      if (truck == null) return false;
      
      // Check if inspection is complete ('ready')
      return truck['inspectionStatus'] == 'ready';
    }).map((u) => u['phone'] as String).toList();

    if (availableDrivers.isEmpty) {
      availableDrivers.add('+919876543210');
    }
    String selectedDriver = editModeTrip?['driverPhone'] ?? availableDrivers.first;
    if (!availableDrivers.contains(selectedDriver)) {
      availableDrivers.add(selectedDriver);
    }

    final initialTruck = controller.trucks.firstWhereOrNull((t) => t['assignedTo'] == selectedDriver)?['truckNo'] as String?;
    String selectedTruck = initialTruck ?? editModeTrip?['truckNo'] ?? 'MH-12-BV-0045';

    final availableTrucks = controller.trucks.map((t) => t['truckNo'] as String).toList();
    if (availableTrucks.isEmpty) availableTrucks.add('MH-12-BV-0045');
    if (!availableTrucks.contains(selectedTruck)) {
      availableTrucks.add(selectedTruck);
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
        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
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
                        StatefulBuilder(
                          builder: (ctx, setSB) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: selectedTruck,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign Truck',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.local_shipping_rounded),
                                    helperText: 'Truck is automatically set based on driver selection.',
                                  ),
                                  items: availableTrucks
                                      .map((t) =>
                                          DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: null, // Disabled: read-only
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: selectedDriver,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign Driver',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_rounded),
                                    helperText: 'Only showing drivers with completed inspections.',
                                  ),
                                  items: availableDrivers.map((d) {
                                    final name = controller.users.firstWhere(
                                        (u) => u['phone'] == d,
                                        orElse: () => {'name': d})['name'];
                                    return DropdownMenuItem(
                                        value: d, child: Text('$name ($d)'));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSB(() {
                                        selectedDriver = val;
                                        final matchedTruck = controller.trucks.firstWhereOrNull((t) => t['assignedTo'] == val);
                                        if (matchedTruck != null) {
                                          final truckNo = matchedTruck['truckNo'] as String;
                                          if (!availableTrucks.contains(truckNo)) {
                                            availableTrucks.add(truckNo);
                                          }
                                          selectedTruck = truckNo;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            );
                          }
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
                decoration: const InputDecoration(
                  labelText: 'Truck Plate Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_rounded),
                ),
                enabled: editModeTruck == null,
                validator: (v) => v!.isEmpty ? 'Field required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Truck Model',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Field required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.toggle_on_rounded),
                ),
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
        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
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
                                        maxLines: 3,
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
                                        maxLines: 4,
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
