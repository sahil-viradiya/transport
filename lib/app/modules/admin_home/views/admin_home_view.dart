import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
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
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/utils/image_url.dart';
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
      _buildVendorsTab(context, isDark),
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
          // Visual order Dashboard, Trucks, Trips, Drivers — mapped to the
          // underlying tab indices [0, 2, 1, 3] so page content stays correct.
          : Obx(() => NavigationBar(
                selectedIndex:
                    _mobileNavOrder.indexOf(controller.currentTabIndex.value),
                onDestinationSelected: (pos) =>
                    controller.changeTabIndex(_mobileNavOrder[pos]),
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
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping_rounded,
                        color: AppColors.primary),
                    label: 'Trucks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.alt_route_outlined),
                    selectedIcon:
                        Icon(Icons.alt_route_rounded, color: AppColors.primary),
                    label: 'Trips',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline_rounded),
                    selectedIcon:
                        Icon(Icons.people_rounded, color: AppColors.primary),
                    label: 'Drivers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon:
                        Icon(Icons.storefront_rounded, color: AppColors.primary),
                    label: 'Vendors',
                  ),
                ],
              )),
      ),
    );
  }

  // ---- Web/desktop shell: dark brand sidebar + top bar ----

  // Display order: Dashboard, Trucks, Trips, Drivers. Each entry carries its
  // own destination tab index so the visual order can differ from the
  // underlying page/index mapping (which many callers reference numerically).
  static const _navItems = [
    (Icons.dashboard_rounded, 'Dashboard', 0),
    (Icons.local_shipping_rounded, 'Trucks', 2),
    (Icons.alt_route_rounded, 'Trips', 1),
    (Icons.people_rounded, 'Drivers', 3),
    (Icons.storefront_rounded, 'Vendors', 4),
  ];

  // Mobile bottom-nav visual position → underlying tab index (same order as the
  // desktop sidebar: Dashboard, Trucks, Trips, Drivers, Vendors).
  static const _mobileNavOrder = [0, 2, 1, 3, 4];

  Widget _buildSidebar() {
    return Container(
      width: 230,
      color: const Color(0xFF081C12), // Dark forest green background
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
                    color: const Color(0xFF10B981), // Bright green brand box
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 22),
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
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w800),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_navItems.length, (i) {
            final (icon, label, tabIndex) = _navItems[i];
            return Obx(() {
              final selected = controller.currentTabIndex.value == tabIndex;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: selected
                      ? const Color(0xFF059669) // Solid medium green selected bg
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => controller.changeTabIndex(tabIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(icon,
                              size: 20,
                              color: selected ? Colors.white : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppText(label,
                                style: AppTextStyle.bodyMedium,
                                color: selected ? Colors.white : const Color(0xFF9CA3AF),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                          if (label != 'Dashboard' && label != 'Drivers')
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: selected ? Colors.white : const Color(0xFF9CA3AF)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          IconButton(
            icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Obx(() {
            final label = _navItems
                .firstWhere((e) => e.$3 == controller.currentTabIndex.value,
                    orElse: () => _navItems.first)
                .$2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label,
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.w700),
                const AppText('Welcome Admin', style: AppTextStyle.labelMedium, color: Color(0xFF6B7280)),
              ],
            );
          }),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _assignTripGuarded(context, isDark),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Assign Trip', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857), // Solid green button
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF047857), // Solid green button
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
            onSelected: (value) {
              if (value == 'truck') {
                _showTruckFormDialog(context, isDark);
              } else if (value == 'driver') {
                _showUserFormDialog(context, isDark);
              } else if (value == 'trip') {
                _assignTripGuarded(context, isDark);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'truck',
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Add Truck'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'driver',
                child: Row(
                  children: [
                    Icon(Icons.person_add_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Add Driver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'trip',
                child: Row(
                  children: [
                    Icon(Icons.assignment_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Assign Trip'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const NotificationBell(color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage('https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop'),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText('Admin User', style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                  AppText('Super Admin', style: AppTextStyle.labelMedium, color: Color(0xFF6B7280)),
                ],
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black54),
            ],
          ),
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
                  child: _buildStatCardOld(s.$1, s.$2, s.$3, s.$4, s.$5, isDark,
                      onTap: s.$6),
                ))
            .toList(),
      );
    });
  }

  Widget _buildStatCardOld(String label, String value, IconData icon, Color bg,
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
    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        // Obx so the dashboard stats + inspection/assignment panels rebuild the
        // moment the live Firestore streams push an update (new inspection
        // submitted, truck/driver counts change, trip status moves) — otherwise
        // these panels are built once and go stale.
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWebStatsGrid(isDark),
              const SizedBox(height: 20),
              _buildWorkflowOverviewCard(isDark),
              const SizedBox(height: 20),
              _buildTodaysTripsOverview(context, isDark),
              const SizedBox(height: 20),
              _buildBottomGrid(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebStatsGrid(bool isDark) {
    final totalTrucks = controller.trucks.length;
    final assignedTrucks = controller.assignedTrucks.length;
    final totalDrivers = controller.users.where((u) => (u['role'] ?? 'driver') == 'driver').length;
    final tripsToday = controller.trips.length;
    final tripsOnWay = controller.trips.where((t) => t['status'] != 'DELIVERED' && t['status'] != 'REJECTED' && t['status'] != 'PENDING').length;
    final completedCount = controller.completedTripsCount;

    final assignedPercent = totalTrucks == 0 ? 0.0 : (assignedTrucks / totalTrucks * 100);

    final stats = [
      ('Total Trucks', '$totalTrucks', 'All Registered', '↑ 8% from last month', Icons.local_shipping_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      ('Assigned Trucks', '$assignedTrucks', '${assignedPercent.toStringAsFixed(1)}% Assigned', '↑ 10% from last month', Icons.assignment_turned_in_rounded, const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      ('Drivers', '$totalDrivers', 'All Active', '↑ 5% from last month', Icons.people_rounded, const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
      ('Trips Today', '${tripsToday.toString().padLeft(2, '0')}', 'Total Trips', '↑ 14% from yesterday', Icons.route_rounded, const Color(0xFFFFEDD5), const Color(0xFFEA580C)),
      ('Trips On Way', '${tripsOnWay.toString().padLeft(2, '0')}', 'Currently On Way', '', Icons.explore_rounded, const Color(0xFFE0F2FE), const Color(0xFF2563EB)),
      ('Trips Completed', '${completedCount.toString().padLeft(2, '0')}', 'Today Completed', '↑ 18% from yesterday', Icons.check_circle_rounded, const Color(0xFFE3FCEF), const Color(0xFF006644)),
    ];

    return LayoutBuilder(builder: (context, cons) {
      final cols = cons.maxWidth >= 1100 ? 6 : (cons.maxWidth >= 700 ? 3 : 2);
      final w = (cons.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: stats.map((s) {
          return SizedBox(
            width: w,
            child: _buildStatCard(s.$1, s.$2, s.$3, s.$4, s.$5, s.$6, s.$7, isDark),
          );
        }).toList(),
      );
    });
  }

  Widget _buildStatCard(String label, String value, String subtitle, String trend, IconData icon, Color iconBg, Color iconColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
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
                AppText(label, style: AppTextStyle.labelMedium, color: const Color(0xFF6B7280), fontWeight: FontWeight.bold),
                const SizedBox(height: 8),
                AppText(value, style: AppTextStyle.headlineMedium, fontWeight: FontWeight.bold),
                const SizedBox(height: 4),
                AppText(subtitle, style: AppTextStyle.labelMedium, color: const Color(0xFF9CA3AF)),
                if (trend.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: Color(0xFF10B981), size: 12),
                      const SizedBox(width: 2),
                      AppText(trend, style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowOverviewCard(bool isDark) {
    final steps = [
      ('Assign Truck', 'Admin assigns\ntruck to driver', Icons.local_shipping_rounded, '01'),
      ('Inspection', 'Driver inspects\n& submits', Icons.fact_check_rounded, '02'),
      ('Admin Review', 'Admin reviews\ninspection', Icons.rate_review_rounded, '03'),
      ('Accept Truck', 'Driver accepts\ntruck', Icons.thumb_up_rounded, '04'),
      ('Assign Trip', 'Admin assigns\ntrip', Icons.assignment_rounded, '05'),
      ('On Way', 'Trip is on the\nway', Icons.explore_rounded, '06'),
      ('Completed', 'Trip completed\nsuccessfully', Icons.task_alt_rounded, '07'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Workflow Overview',
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.bold),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Container(
                    width: 60,
                    height: 2,
                    margin: const EdgeInsets.only(top: 24),
                    color: const Color(0xFFE5EAE7),
                  );
                }
                final idx = i ~/ 2;
                final step = steps[idx];
                return SizedBox(
                  width: 130,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
                        ),
                        child: Icon(step.$3, color: const Color(0xFF047857), size: 22),
                      ),
                      const SizedBox(height: 12),
                      AppText(step.$1,
                          style: AppTextStyle.bodyMedium,
                          fontWeight: FontWeight.bold,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      AppText(step.$2,
                          style: AppTextStyle.labelMedium,
                          fontSize: 10,
                          color: const Color(0xFF6B7280),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AppText(step.$4,
                            style: AppTextStyle.labelMedium,
                            fontSize: 11,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.bold),
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

  Widget _buildTodaysTripsOverview(BuildContext context, bool isDark) {
    final realTrips = controller.trips.where((t) => t['status'] != 'DELIVERED').toList();

    final displayTrips = <Map<String, dynamic>>[];
    for (final rt in realTrips) {
      final ts = rt['createdAt'] ?? rt['date'];
      String startedTime = '08:30 AM';
      if (ts != null) {
        try {
          final dt = ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : DateTime.parse(ts.toString()));
          final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          startedTime = "${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
        } catch (_) {}
      }

      displayTrips.add({
        'id': rt['id'].toString(),
        'driverName': controller.driverNameFor(rt['driverPhone'].toString()),
        'truckNo': rt['truckNo'] ?? 'No Truck',
        'status': rt['status'] == 'EN_ROUTE_VENDOR' || rt['status'] == 'ACTIVE NOW' ? 'On Way' : (rt['status'] == 'LOADING' ? 'Inspection' : rt['status']),
        'loadingPassId': rt['loadingPassId'] ?? '—',
        'pickupLocation': rt['pickupCity'] ?? rt['pickupLocation'] ?? '—',
        'dropCity': rt['dropCity'] ?? '—',
        'startedTime': startedTime,
        'distance': '${rt['remainingDistance'] ?? '154'} km',
        'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
      });
    }

    if (displayTrips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            const AppText("No active trips today", style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 4),
            const AppText("New trips will show up here once assigned.", style: AppTextStyle.labelMedium, color: Colors.grey),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText("Today's Trips Overview", style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
              Row(
                children: [
                  TextButton(
                    onPressed: () => controller.changeTabIndex(1),
                    child: const AppText('View All Trips', style: AppTextStyle.labelMedium, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayTrips.map((t) {
                final status = t['status']?.toString() ?? 'Pending';
                Color statusColor = const Color(0xFF6B7280);
                Color statusBg = const Color(0xFFF1F5F9);
                if (status == 'On Way') {
                  statusColor = const Color(0xFF047857);
                  statusBg = const Color(0xFFDCFCE7);
                } else if (status == 'Assigned') {
                  statusColor = const Color(0xFF2563EB);
                  statusBg = const Color(0xFFDBEAFE);
                } else if (status == 'Inspection') {
                  statusColor = const Color(0xFFD97706);
                  statusBg = const Color(0xFFFEF3C7);
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      controller.selectedTripId.value = t['id'].toString();
                      AppSnackBar.showSuccess(title: 'Trip Selected', message: 'Tracking selected trip ${t['id']} on dashboard.');
                    },
                    onDoubleTap: () {
                      Get.to(() => const AdminTripDetailsView(), arguments: {'tripId': t['id']});
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(t['avatar']),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(t['driverName'], style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                    AppText(t['truckNo'], style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFF6B7280)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: AppText(status, style: AppTextStyle.labelMedium, fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  AppText(t['id'], style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF9CA3AF)),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: t['id']));
                                      AppSnackBar.showSuccess(title: 'Copied', message: 'Trip ID copied to clipboard');
                                    },
                                  ),
                                ],
                              ),
                              AppText(t['loadingPassId'], style: AppTextStyle.labelMedium, color: const Color(0xFFEA580C), fontWeight: FontWeight.bold),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              AppText(t['pickupLocation'], style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: AppText(t['dropCity'], style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText('Started: ${t['startedTime']}', style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFF9CA3AF)),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 2),
                                  AppText(t['distance'], style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGrid(BuildContext context, bool isDark) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTruckAssignmentsPanel(context, isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildTruckInspectionPendingPanel(context, isDark)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _buildQuickActionsPanel(context, isDark),
                const SizedBox(height: 16),
                _buildRecentNotificationsPanel(isDark),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildTruckAssignmentsPanel(context, isDark),
        const SizedBox(height: 16),
        _buildTruckInspectionPendingPanel(context, isDark),
        const SizedBox(height: 16),
        _buildQuickActionsPanel(context, isDark),
        const SizedBox(height: 16),
        _buildRecentNotificationsPanel(isDark),
      ],
    );
  }

  Widget _buildTruckAssignmentsPanel(BuildContext context, bool isDark) {
    final assigned = controller.trucks.where((t) => (t['assignedTo'] ?? '').toString().isNotEmpty).toList();
    
    final displayAssignments = <Map<String, dynamic>>[];
    for (final t in assigned) {
      final driverPhone = t['assignedTo'].toString();
      final driverName = controller.driverNameFor(driverPhone);
      final driverTrip = controller.trips.firstWhereOrNull((trip) =>
          trip['driverPhone'].toString() == driverPhone && trip['status'] != 'DELIVERED');
      String status = 'Assigned';
      if (driverTrip != null) {
        final ts = driverTrip['status']?.toString() ?? '';
        status = ts == 'EN_ROUTE_VENDOR' || ts == 'ACTIVE NOW' ? 'On Way' : (ts == 'LOADING' ? 'Inspection' : ts);
      }
      displayAssignments.add({
        'driverName': driverName,
        'truckNo': t['truckNo'],
        'status': status,
        'date': '11-07-2026 08:30 AM',
        'tripId': driverTrip != null ? driverTrip['id'].toString() : '',
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
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
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.trucks.isNotEmpty) {
                    _showAssignTruckDialog(context, controller.trucks.first);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Assign Truck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Driver Name', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Truck Number', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Status', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Assigned On', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                ],
              ),
              if (displayAssignments.isEmpty)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AppText('No active assignments', style: AppTextStyle.bodyMedium, color: Colors.grey.shade500),
                    ),
                    const SizedBox(),
                    const SizedBox(),
                    const SizedBox(),
                  ],
                ),
              ...displayAssignments.map((a) {
                final status = a['status']?.toString() ?? 'Pending';
                Color statusColor = const Color(0xFF6B7280);
                Color statusBg = const Color(0xFFF1F5F9);
                if (status == 'On Way') {
                  statusColor = const Color(0xFF047857);
                  statusBg = const Color(0xFFDCFCE7);
                } else if (status == 'Assigned') {
                  statusColor = const Color(0xFF2563EB);
                  statusBg = const Color(0xFFDBEAFE);
                } else if (status == 'Inspection') {
                  statusColor = const Color(0xFFD97706);
                  statusBg = const Color(0xFFFEF3C7);
                }

                final tripId = a['tripId']?.toString() ?? '';
                final hasTrip = tripId.isNotEmpty;

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: InkWell(
                        onTap: hasTrip ? () {
                          controller.selectedTripId.value = tripId;
                          AppSnackBar.showSuccess(title: 'Trip Selected', message: 'Tracking selected trip $tripId.');
                        } : null,
                        child: AppText(
                          a['driverName'],
                          style: AppTextStyle.bodyMedium,
                          color: hasTrip ? const Color(0xFF047857) : null,
                          fontWeight: hasTrip ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppText(a['truckNo'], style: AppTextStyle.bodyMedium)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: AppText(status, style: AppTextStyle.labelMedium, fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppText(a['date'], style: AppTextStyle.labelMedium, color: const Color(0xFF6B7280))),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => controller.changeTabIndex(2),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: AppText('View All Assignments', style: AppTextStyle.labelMedium, color: Color(0xFF047857), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckInspectionPendingPanel(BuildContext context, bool isDark) {
    final pending = controller.trucks.where((t) {
      final status = (t['inspectionStatus'] ?? '').toString();
      final hasDriver = (t['assignedTo'] ?? '').toString().isNotEmpty;
      return hasDriver && (status == 'inspected_pending_review' || status == 'pending');
    }).toList();
    
    final displayInspections = <Map<String, dynamic>>[];
    for (final t in pending) {
      final driverPhone = t['assignedTo'].toString();
      displayInspections.add({
        'truckNo': t['truckNo'],
        'driverName': controller.driverNameFor(driverPhone),
        'inspectionStatus': t['inspectionStatus'] == 'inspected_pending_review' ? 'Pending Review' : 'Pending Driver',
        'rawTruck': t,
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
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
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText('${displayInspections.length} Pending', style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFFD97706), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Truck No.', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Driver Name', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppText('Status', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold)),
                ],
              ),
              if (displayInspections.isEmpty)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AppText('No pending inspections', style: AppTextStyle.bodyMedium, color: Colors.grey.shade500),
                    ),
                    const SizedBox(),
                    const SizedBox(),
                  ],
                ),
              ...displayInspections.map((i) {
                final rawTruck = i['rawTruck'] as Map<String, dynamic>;
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: InkWell(
                        onTap: () => _showInspectionReviewDialog(context, isDark, rawTruck),
                        child: Text(
                          i['truckNo'],
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppText(i['driverName'], style: AppTextStyle.bodyMedium)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: i['inspectionStatus'] == 'Pending Review' ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: AppText(
                            i['inspectionStatus'] == 'Pending Review' ? 'Review' : 'Pending',
                            style: AppTextStyle.labelMedium,
                            fontSize: 11,
                            color: i['inspectionStatus'] == 'Pending Review' ? const Color(0xFFD97706) : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
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
          TextButton(
            onPressed: () => controller.changeTabIndex(2),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: AppText('View All Inspections', style: AppTextStyle.labelMedium, color: Color(0xFF047857), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(BuildContext context, bool isDark) {
    Widget actionCard(IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                AppText(label, style: AppTextStyle.labelMedium, color: color, fontWeight: FontWeight.bold),
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
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('Quick Actions', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
          const SizedBox(height: 12),
          Row(
            children: [
              actionCard(Icons.local_shipping_rounded, 'Add Truck', const Color(0xFF047857), () => _showTruckFormDialog(context, isDark)),
              const SizedBox(width: 8),
              actionCard(Icons.explore_rounded, 'Assign Trip', const Color(0xFF2563EB), () => _assignTripGuarded(context, isDark)),
              const SizedBox(width: 8),
              actionCard(Icons.person_add_rounded, 'Add Driver', const Color(0xFF7E22CE), () => _showUserFormDialog(context, isDark)),
              const SizedBox(width: 8),
              actionCard(Icons.assignment_rounded, 'Loading Pass', const Color(0xFFEA580C), () {
                final withPass = controller.trips.where((t) => (t['loadingPassId'] ?? '').toString().isNotEmpty).toList();
                if (withPass.isNotEmpty) {
                  _showSetDestinationDialog(withPass.first);
                } else {
                  AppSnackBar.showInfo(title: 'Loading Pass', message: 'No active trips with loading passes to approve right now.');
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotificationsPanel(bool isDark) {
    return Obx(() {
      final List<Map<String, dynamic>> displayNotifications = [];
      
      // Load real notifications from database
      if (Get.isRegistered<NotificationsController>()) {
        final notifs = Get.find<NotificationsController>();
        for (final n in notifs.items.take(4)) {
          final ts = n['createdAt'];
          String when = 'Just now';
          try {
            if (ts is Timestamp) {
              final dt = ts.toDate();
              final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
              when = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
            }
          } catch (_) {}

          final body = (n['body'] ?? '').toString();
          String type = 'info';
          if (body.contains('complete') || body.contains('completed')) {
            type = 'complete';
          } else if (body.contains('inspection') || body.contains('pending')) {
            type = 'pending';
          } else if (body.contains('accepted') || body.contains('accept')) {
            type = 'accept';
          }

          displayNotifications.add({
            'title': n['title']?.toString() ?? 'Notification',
            'body': body,
            'date': when,
            'type': type,
          });
        }
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppText('Recent Notifications', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        AppPopup.showLoading(message: 'Resetting DB...');
                        await controller.clearDatabase();
                        AppPopup.hideLoading();
                        AppSnackBar.showSuccess(title: 'Reset Success', message: 'All active data reset to initial state.');
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.error),
                      label: const Text('Reset Data', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    if (Get.isRegistered<NotificationsController>()) {
                      const NotificationBell().open(Get.context!);
                    }
                  },
                  child: const AppText('View All', style: AppTextStyle.labelMedium, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 36, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const AppText('No new notifications', style: AppTextStyle.bodyMedium, color: Colors.grey),
                  ],
                ),
              ),
            if (displayNotifications.isNotEmpty)
              Column(
                children: displayNotifications.map((n) {
                final type = n['type'];
                IconData icon = Icons.notifications_active_outlined;
                Color iconColor = const Color(0xFF2563EB);
                Color iconBg = const Color(0xFFDBEAFE);
                if (type == 'complete') {
                  icon = Icons.check_circle_outline_rounded;
                  iconColor = const Color(0xFF047857);
                  iconBg = const Color(0xFFDCFCE7);
                } else if (type == 'pending') {
                  icon = Icons.warning_amber_rounded;
                  iconColor = const Color(0xFFEA580C);
                  iconBg = const Color(0xFFFFEDD5);
                } else if (type == 'accept') {
                  icon = Icons.thumb_up_alt_rounded;
                  iconColor = const Color(0xFF7E22CE);
                  iconBg = const Color(0xFFF3E8FF);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(n['body'], style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                            const SizedBox(height: 2),
                            AppText(n['date'], style: AppTextStyle.labelMedium, fontSize: 11, color: const Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
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
  /// Priority header for an admin trip card: leads with Driver Name + Truck
  /// Number (fastest way to recognise a trip on the floor), then Trip ID and
  /// Loading Pass, with the live status chip + delete on the right.
  Widget _buildTripCardHeader(BuildContext context, bool isDark,
      Map<String, dynamic> trip, bool isTripActive) {
    final status = (trip['status'] ?? 'ASSIGNED').toString();
    final driverName = (trip['driverName'] ?? '').toString().trim().isNotEmpty
        ? trip['driverName'].toString()
        : controller.driverNameFor((trip['driverPhone'] ?? '').toString());
    final truckNo = (trip['truckNo'] ?? '—').toString();
    final tripId = (trip['id'] ?? '—').toString();
    final loadingPass = (trip['loadingPassId'] ?? '').toString();

    final chipBg = isTripActive
        ? const Color(0xFFFFF0B3)
        : (status == 'DELIVERED'
            ? const Color(0xFFE3FCEF)
            : AppColors.primaryLight);
    final chipFg = isTripActive
        ? const Color(0xFFBF2600)
        : (status == 'DELIVERED'
            ? const Color(0xFF006644)
            : AppColors.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                      driverName.trim().isEmpty ? 'Driver' : driverName,
                      style: AppTextStyle.headlineSmall,
                      fontWeight: FontWeight.w800,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: AppText('Truck: $truckNo',
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.w600,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppText(status,
                      style: AppTextStyle.labelMedium,
                      color: chipFg,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  padding: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(),
                  onPressed: () => controller.deleteTrip(trip['id']),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tripMetaChip(
                  isDark, Icons.tag_rounded, 'Trip ID', tripId),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tripMetaChip(isDark, Icons.confirmation_number_rounded,
                  'Loading Pass', loadingPass.isEmpty ? '—' : loadingPass),
            ),
          ],
        ),
      ],
    );
  }

  /// Compact labelled chip used in the trip-card priority header.
  Widget _tripMetaChip(
      bool isDark, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label,
                    style: AppTextStyle.labelMedium,
                    color: AppColors.textHint),
                AppText(value,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                      // Priority header: the fastest way to identify a trip —
                      // Driver Name + Truck Number lead, then Trip ID + Loading
                      // Pass, with the live status chip on the right.
                      _buildTripCardHeader(context, isDark, trip, isTripActive),
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
        onPressed: () => _assignTripGuarded(context, isDark),
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

    // Distinguish the intermediate inspection states so the admin knows whose
    // action is pending: driver still to inspect, admin to review, or driver to
    // accept after approval.
    (String, Color, IconData) badge;
    final needsReview = inspection == 'inspected_pending_review';
    if (assignedTo.isEmpty) {
      badge = ('Not Assigned', AppColors.textSecondary, Icons.person_off_rounded);
    } else if (inspection == 'ready') {
      badge = ('Ready ✓', AppColors.success, Icons.verified_rounded);
    } else if (inspection == 'problem') {
      badge = ('Problem Reported', AppColors.error, Icons.report_problem_rounded);
    } else if (needsReview) {
      badge = ('Review Pending', AppColors.tertiaryDark, Icons.rate_review_rounded);
    } else if (inspection == 'approved_pending_accept') {
      badge = ('Waiting Driver Accept', AppColors.info, Icons.hourglass_bottom_rounded);
    } else {
      badge = ('Inspection Pending', AppColors.textSecondary, Icons.pending_rounded);
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
            // When the driver has submitted an inspection, the primary action is
            // to review it; otherwise assign/reassign the truck.
            if (needsReview)
              TextButton.icon(
                onPressed: () =>
                    _showInspectionReviewDialog(context, isDark, truck),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: const Text('Review'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.tertiaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              )
            else
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

  /// Small role pill (Driver / Admin) for the drivers list.
  Widget _roleChip(String role) {
    final isAdmin = role == 'admin';
    final color = isAdmin ? const Color(0xFF7E22CE) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: AppText(isAdmin ? 'Admin' : 'Driver',
          style: AppTextStyle.labelMedium,
          color: color,
          fontWeight: FontWeight.bold),
    );
  }

  /// Which documents are on file for a driver (photo / driving licence /
  /// heavy-vehicle licence). Uploaded ones are tappable → open a full-screen
  /// viewer so the admin can actually see the document.
  Widget _driverDocsRow(BuildContext context, Map<String, dynamic> user) {
    String url(String key) => (user[key] ?? '').toString().trim();
    final name = (user['name'] ?? 'Driver').toString();
    return Row(
      children: [
        const AppText('Documents:',
            style: AppTextStyle.labelMedium, color: AppColors.textHint),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _docStatusChip(context, 'Photo', url('avatarUrl'), '$name — Photo'),
              _docStatusChip(context, 'Licence', url('drivingLicenceUrl'),
                  '$name — Driving Licence'),
              _docStatusChip(context, 'Heavy', url('heavyLicenceUrl'),
                  '$name — Heavy Vehicle Licence'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _docStatusChip(
      BuildContext context, String label, String docUrl, String title) {
    final present = docUrl.isNotEmpty && docUrl.startsWith('http');
    final color = present ? AppColors.success : AppColors.textHint;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              present
                  ? Icons.visibility_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 13,
              color: color),
          const SizedBox(width: 4),
          AppText(label,
              style: AppTextStyle.labelMedium,
              color: color,
              fontWeight: FontWeight.w600),
        ],
      ),
    );
    if (!present) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showImageViewer(context, docUrl, title),
      child: chip,
    );
  }

  /// Full-screen image viewer (with proxy + graceful loading/error states).
  void _showImageViewer(BuildContext context, String url, String title) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(title,
                        style: AppTextStyle.bodyMedium,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  corsSafeImageUrl(url),
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  },
                  errorBuilder: (ctx, err, stack) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            color: Colors.white54, size: 48),
                        SizedBox(height: 12),
                        AppText('Image load nahi hui',
                            style: AppTextStyle.bodyMedium,
                            color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
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
                      AppText('No drivers registered yet. Tap "+" to add one.',
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
              final isDriver = (user['role'] ?? 'driver') != 'admin';

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
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(corsSafeImageUrl(
                              (user['avatarUrl'] ??
                                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150')
                                  .toString())),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppText(user['name'] ?? '',
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  _roleChip(user['role'] ?? 'driver'),
                                ],
                              ),
                              const SizedBox(height: 2),
                              AppText(user['phone'] ?? '',
                                  style: AppTextStyle.labelMedium),
                              if (isDriver) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    _availabilityBadge(user),
                                    if (controller.isOnLeave(user))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.tertiaryLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.beach_access_rounded,
                                                size: 12,
                                                color: AppColors.tertiaryDark),
                                            SizedBox(width: 4),
                                            AppText('On Leave',
                                                style:
                                                    AppTextStyle.labelMedium,
                                                color: AppColors.tertiaryDark,
                                                fontWeight: FontWeight.bold),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Role switch + leave toggle + delete.
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: AppColors.textSecondary),
                          onSelected: (value) {
                            if (value == 'delete') {
                              controller.deleteUser(user['phone']);
                            } else if (value == 'leave') {
                              controller.setDriverOnLeave(user['phone'], true);
                            } else if (value == 'unleave') {
                              controller.setDriverOnLeave(
                                  user['phone'], false);
                            } else if (value == 'admin' ||
                                value == 'driver') {
                              if (value != user['role']) {
                                controller.editUserRole(user['phone'], value);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: isDriver ? 'admin' : 'driver',
                              child: Row(
                                children: [
                                  Icon(
                                      isDriver
                                          ? Icons.admin_panel_settings_rounded
                                          : Icons.local_shipping_rounded,
                                      size: 18,
                                      color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  AppText(
                                      isDriver
                                          ? 'Make Admin'
                                          : 'Make Driver',
                                      style: AppTextStyle.bodyMedium),
                                ],
                              ),
                            ),
                            if (isDriver)
                              PopupMenuItem(
                                value: controller.isOnLeave(user)
                                    ? 'unleave'
                                    : 'leave',
                                child: Row(
                                  children: [
                                    Icon(
                                        controller.isOnLeave(user)
                                            ? Icons.event_available_rounded
                                            : Icons.beach_access_rounded,
                                        size: 18,
                                        color: AppColors.tertiaryDark),
                                    const SizedBox(width: 10),
                                    AppText(
                                        controller.isOnLeave(user)
                                            ? 'Back On Duty'
                                            : 'Mark On Leave',
                                        style: AppTextStyle.bodyMedium),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: AppColors.error),
                                  SizedBox(width: 10),
                                  AppText('Delete',
                                      style: AppTextStyle.bodyMedium,
                                      color: AppColors.error),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Document records — ties into driver registration uploads.
                    if (isDriver) ...[
                      const Divider(height: 20),
                      _driverDocsRow(context, user),
                    ],
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

  // --- TAB 5: VENDORS (predefined pickup sources) ---
  Widget _buildVendorsTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          if (controller.vendors.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 60, color: AppColors.textHint),
                      SizedBox(height: 12),
                      AppText('No vendors yet. Tap "+" to add one.',
                          style: AppTextStyle.bodyLarge),
                      SizedBox(height: 4),
                      AppText(
                          'Vendor ek baar add karein, phir trip me bas select karein.',
                          style: AppTextStyle.labelMedium,
                          color: AppColors.textHint),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: controller.vendors.length,
            itemBuilder: (context, index) {
              final v = controller.vendors[index];
              final loc =
                  (v['pickupLocation'] ?? v['location'] ?? '').toString();
              final cityDistrict = [
                (v['city'] ?? '').toString(),
                (v['district'] ?? '').toString(),
              ].where((s) => s.isNotEmpty).join(', ');
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText((v['name'] ?? 'Vendor').toString(),
                              style: AppTextStyle.bodyLarge,
                              fontWeight: FontWeight.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (loc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            AppText(loc,
                                style: AppTextStyle.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          if (cityDistrict.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            AppText(cityDistrict,
                                style: AppTextStyle.labelMedium,
                                color: AppColors.textHint),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20),
                      onPressed: () => _showVendorFormDialog(context, isDark,
                          editVendor: v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                      onPressed: () => controller.deleteVendor(
                          (v['id'] ?? '').toString(),
                          name: (v['name'] ?? '').toString()),
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
        onPressed: () => _showVendorFormDialog(context, isDark),
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

  /// Daily gate: the admin can only create a trip once every on-duty driver has
  /// a truck assigned. Otherwise it lists who's still pending and blocks.
  void _assignTripGuarded(BuildContext context, bool isDark) {
    if (controller.canCreateTrip) {
      _showTripFormDialog(context, isDark);
      return;
    }
    final pending = controller.driversWithoutTruck;
    final noDrivers = controller.rosterDrivers.isEmpty;
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: AppColors.tertiaryDark),
            SizedBox(width: 8),
            Expanded(
              child: AppText('Pehle Trucks Assign Karein',
                  style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              noDrivers
                  ? 'Koi on-duty driver nahi hai. Pehle driver add karein ya leave hata kar duty par laayein.'
                  : 'Trip banane se pehle har on-duty driver ko truck assign karna zaroori hai. '
                      'Ye drivers abhi baaki hain:',
              style: AppTextStyle.bodyMedium,
            ),
            if (!noDrivers) ...[
              const SizedBox(height: 12),
              ...pending.take(8).map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.person_off_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            (u['name'] ?? u['phone'] ?? 'Driver').toString(),
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (pending.length > 8)
                AppText('+${pending.length - 8} aur…',
                    style: AppTextStyle.labelMedium, color: AppColors.textHint),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Theek Hai'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Get.back();
              controller.changeTabIndex(2); // jump to Trucks tab
            },
            child: const Text('Trucks Kholo',
                style: TextStyle(color: Colors.white)),
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
      // On-leave drivers can't be assigned trips.
      if (controller.isOnLeave(u)) return false;
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

    // Vendor is predefined — admin just selects it and its location auto-fills.
    // In edit mode, pre-select the vendor whose name matches the saved trip.
    String? selectedVendorId = editModeTrip == null
        ? null
        : controller.vendors.firstWhereOrNull((v) =>
            (v['name'] ?? '').toString() ==
            (editModeTrip['vendorName'] ?? '').toString())?['id'];

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
                        // Trip ID is auto-generated — no manual entry.
                        if (editModeTrip == null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tag_rounded,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: AppText(
                                    'Trip ID automatically generate hogi.',
                                    style: AppTextStyle.labelMedium,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Vendor selector (predefined) — auto-fills pickup info.
                        StatefulBuilder(
                          builder: (ctx, setVendorState) {
                            return DropdownButtonFormField<String>(
                              initialValue: selectedVendorId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Vendor',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.storefront_rounded),
                                helperText:
                                    'Predefined vendor select karein — pickup details auto-fill ho jayengi.',
                              ),
                              items: [
                                ...controller.vendors.map((v) => DropdownMenuItem(
                                      value: (v['id'] ?? '').toString(),
                                      child: Text(
                                        (v['name'] ?? 'Vendor').toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                                const DropdownMenuItem(
                                  value: '__add__',
                                  child: Text('➕ Add New Vendor'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == '__add__') {
                                  _showVendorFormDialog(context, isDark);
                                  return;
                                }
                                if (val == null) return;
                                final v = controller.vendors
                                    .firstWhereOrNull((e) => e['id'] == val);
                                if (v == null) return;
                                setVendorState(() => selectedVendorId = val);
                                final loc =
                                    (v['pickupLocation'] ?? v['location'] ?? '')
                                        .toString();
                                vendorNameCtrl.text = (v['name'] ?? '').toString();
                                vendorLocCtrl.text = loc;
                                pickupLocCtrl.text = loc;
                                pickupCityCtrl.text = (v['city'] ?? '').toString();
                                pickupDistrictCtrl.text =
                                    (v['district'] ?? '').toString();
                                if (v['latitude'] != null) {
                                  pickupLatCtrl.text = v['latitude'].toString();
                                }
                                if (v['longitude'] != null) {
                                  pickupLngCtrl.text = v['longitude'].toString();
                                }
                              },
                              // Vendor is required for new trips; legacy trips
                              // being edited may predate the vendor list.
                              validator: (v) {
                                if (editModeTrip != null) return null;
                                return (v == null || v.isEmpty || v == '__add__')
                                    ? 'Vendor select karein'
                                    : null;
                              },
                            );
                          },
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
                        // --- Material / per-trip details (vendor set above) ---
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

  // 1b. ADD / EDIT VENDOR DIALOG
  /// Create/edit a predefined vendor (minimal location details). Once saved,
  /// admins just pick it in the trip form and its pickup info auto-fills.
  void _showVendorFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editVendor}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: editVendor?['name'] ?? '');
    final locCtrl = TextEditingController(
        text: (editVendor?['pickupLocation'] ?? editVendor?['location'] ?? '')
            .toString());
    final cityCtrl = TextEditingController(text: editVendor?['city'] ?? '');
    final districtCtrl =
        TextEditingController(text: editVendor?['district'] ?? '');
    final latCtrl = TextEditingController(
        text: editVendor?['latitude']?.toString() ?? '');
    final lngCtrl = TextEditingController(
        text: editVendor?['longitude']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
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
                AppText(editVendor != null ? 'Edit Vendor' : 'Add Vendor',
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold),
                const Divider(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vendor Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.storefront_rounded),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: locCtrl,
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
                                      '${locCtrl.text.trim()}, ${cityCtrl.text.trim()}';
                                  await _resolveCoordinates(
                                      context, query, latCtrl, lngCtrl);
                                },
                              ),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: cityCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'City',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.location_city_rounded),
                                  ),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: districtCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'District',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.map_rounded),
                                  ),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: latCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.my_location_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: lngCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.my_location_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(sheetCtx).pop(),
                                child: const AppText('Cancel',
                                    style: AppTextStyle.bodyMedium),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;
                                  final data = <String, dynamic>{
                                    if (editVendor?['id'] != null)
                                      'id': editVendor!['id'],
                                    'name': nameCtrl.text.trim(),
                                    'pickupLocation': locCtrl.text.trim(),
                                    'city': cityCtrl.text.trim(),
                                    'district': districtCtrl.text.trim(),
                                    'latitude':
                                        double.tryParse(latCtrl.text.trim()),
                                    'longitude':
                                        double.tryParse(lngCtrl.text.trim()),
                                  };
                                  Navigator.of(sheetCtx).pop();
                                  controller.saveVendor(data);
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

    // Driver document uploads (bytes so it's web + mobile safe).
    Uint8List? photoBytes;
    Uint8List? drivingLicenceBytes;
    Uint8List? heavyLicenceBytes;
    bool heavyApplicable = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(builder: (bottomSheetCtx, setSheetState) {
          Future<void> pick(void Function(Uint8List) assign) async {
            final picked = await ImagePickerHelper.pickFromGallery();
            if (picked != null) setSheetState(() => assign(picked.bytes));
          }

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
                  AppText(
                    role == 'driver' ? 'Register Driver' : 'Add User Profile',
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
                                labelText: 'Full Name',
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
                              initialValue: role,
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
                                if (val != null) {
                                  setSheetState(() => role = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            // Drivers: document uploads. Admins: avatar URL.
                            if (role == 'driver') ...[
                              const AppText('Driver Documents',
                                  style: AppTextStyle.bodyLarge,
                                  fontWeight: FontWeight.w700),
                              const SizedBox(height: 4),
                              const AppText(
                                  'Complete driver record ke liye photo aur licence upload karein.',
                                  style: AppTextStyle.labelMedium,
                                  color: AppColors.textHint),
                              const SizedBox(height: 12),
                              _docUploadTile(
                                isDark: isDark,
                                icon: Icons.account_circle_rounded,
                                label: 'Driver Photo',
                                hint: 'Face photo for the record',
                                bytes: photoBytes,
                                onTap: () =>
                                    pick((b) => photoBytes = b),
                              ),
                              const SizedBox(height: 10),
                              _docUploadTile(
                                isDark: isDark,
                                icon: Icons.badge_rounded,
                                label: 'Driving Licence',
                                hint: 'Front side of the licence',
                                bytes: drivingLicenceBytes,
                                onTap: () =>
                                    pick((b) => drivingLicenceBytes = b),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: heavyApplicable,
                                activeThumbColor: AppColors.primary,
                                title: const AppText('Heavy Vehicle Applicable?',
                                    style: AppTextStyle.bodyMedium,
                                    fontWeight: FontWeight.w600),
                                subtitle: const AppText(
                                    'On karein to Heavy Vehicle Licence mandatory hai.',
                                    style: AppTextStyle.labelMedium,
                                    color: AppColors.textHint),
                                onChanged: (v) =>
                                    setSheetState(() => heavyApplicable = v),
                              ),
                              if (heavyApplicable) ...[
                                const SizedBox(height: 6),
                                _docUploadTile(
                                  isDark: isDark,
                                  icon: Icons.local_shipping_rounded,
                                  label: 'Heavy Vehicle Licence',
                                  hint: 'Mandatory for heavy vehicles',
                                  bytes: heavyLicenceBytes,
                                  required: true,
                                  onTap: () =>
                                      pick((b) => heavyLicenceBytes = b),
                                ),
                              ],
                            ] else
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
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    // Heavy licence is mandatory only when the
                                    // heavy-vehicle toggle is on.
                                    if (role == 'driver' &&
                                        heavyApplicable &&
                                        heavyLicenceBytes == null) {
                                      AppSnackBar.showWarning(
                                        title: 'Heavy Licence Required',
                                        message:
                                            'Heavy vehicle applicable hai — licence upload karein.',
                                      );
                                      return;
                                    }
                                    final phone = phoneCtrl.text
                                        .trim()
                                        .replaceAll(' ', '');
                                    Navigator.of(bottomSheetCtx).pop();
                                    if (role == 'driver') {
                                      controller.createDriverWithDocuments(
                                        {
                                          'name': nameCtrl.text.trim(),
                                          'phone': phone,
                                          'role': 'driver',
                                        },
                                        photoBytes: photoBytes,
                                        drivingLicenceBytes:
                                            drivingLicenceBytes,
                                        heavyLicenceBytes: heavyLicenceBytes,
                                      );
                                    } else {
                                      controller.createUser({
                                        'name': nameCtrl.text.trim(),
                                        'phone': phone,
                                        'role': role,
                                        'avatarUrl': avatarCtrl.text.trim(),
                                      });
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
        });
      },
    );
  }

  /// A tappable document-upload tile that shows the picked image thumbnail once
  /// selected, or an upload prompt otherwise. Used in driver registration.
  Widget _docUploadTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required String hint,
    required Uint8List? bytes,
    required VoidCallback onTap,
    bool required = false,
  }) {
    final hasImage = bytes != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
                ? AppColors.success.withValues(alpha: 0.5)
                : (required
                    ? AppColors.error.withValues(alpha: 0.4)
                    : (isDark ? Colors.white24 : AppColors.border)),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasImage
                  ? Image.memory(bytes,
                      width: 48, height: 48, fit: BoxFit.cover)
                  : Container(
                      width: 48,
                      height: 48,
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      child:
                          Icon(icon, color: AppColors.primary, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText(label,
                          style: AppTextStyle.bodyMedium,
                          fontWeight: FontWeight.w700),
                      if (required)
                        const AppText(' *',
                            style: AppTextStyle.bodyMedium,
                            color: AppColors.error,
                            fontWeight: FontWeight.w700),
                    ],
                  ),
                  AppText(hasImage ? 'Uploaded — tap to change' : hint,
                      style: AppTextStyle.labelMedium,
                      color: hasImage
                          ? AppColors.success
                          : AppColors.textHint),
                ],
              ),
            ),
            Icon(
              hasImage
                  ? Icons.check_circle_rounded
                  : Icons.upload_file_rounded,
              color: hasImage ? AppColors.success : AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
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
