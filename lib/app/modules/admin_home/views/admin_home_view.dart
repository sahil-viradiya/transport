import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/widgets/notification_bell.dart';
import 'package:transport/widgets/animations.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import '../controllers/admin_home_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/notifications_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/presentation/widgets/desktop_admin_scaffold.dart';
import 'package:transport/app/core/utils/truck_owner_pass_pdf_generator.dart';
import 'admin_trip_details_view.dart';
import 'truck_assignment_dashboard.dart';

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
      _buildCustomersTab(context, isDark),
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
      // The mobile branch below remains unchanged. On wide screens the same
      // feature content is composed in the shared desktop presentation shell.
      content = DesktopAdminScaffold(
        sidebar: _buildSidebar(),
        topNavigation: _buildTopBar(context, isDark),
        child: content,
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
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.error),
                    tooltip: 'Logout Session',
                    onPressed: controller.logout,
                  ),
                ],
              ),
        body: content,
        bottomNavigationBar: isWide
            ? null
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
                      selectedIcon: Icon(Icons.analytics_rounded,
                          color: AppColors.primary),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.alt_route_outlined),
                      selectedIcon: Icon(Icons.alt_route_rounded,
                          color: AppColors.primary),
                      label: 'Trips',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline_rounded),
                      selectedIcon:
                          Icon(Icons.people_rounded, color: AppColors.primary),
                      label: 'Drivers',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping_rounded,
                          color: AppColors.primary),
                      label: 'Trucks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded,
                          color: AppColors.primary),
                      label: 'Vendors',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.apartment_outlined),
                      selectedIcon: Icon(Icons.apartment_rounded,
                          color: AppColors.primary),
                      label: 'Customers',
                    ),
                  ],
                )),
      ),
    );
  }

  // ---- Web/desktop shell: dark brand sidebar + top bar ----

  static const _navItems = [
    (Icons.dashboard_rounded, 'Dashboard', 0),
    (Icons.alt_route_rounded, 'Trips', 1),
    (Icons.people_rounded, 'Drivers', 3),
    (Icons.local_shipping_rounded, 'Trucks', 2),
    (Icons.storefront_rounded, 'Vendors', 4),
    (Icons.apartment_rounded, 'Customers', 5),
  ];

  static const _mobileNavOrder = [0, 1, 3, 2, 4, 5];

  static const _monthNames = [
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFF059669) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => controller.changeTabIndex(tabIndex),
                      hoverColor: Colors.white.withValues(alpha: 0.08),
                      splashColor: Colors.white.withValues(alpha: 0.12),
                      mouseCursor: SystemMouseCursors.click,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                icon,
                                key: ValueKey('sb_icon_${tabIndex}_$selected'),
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppText(label,
                                  style: AppTextStyle.bodyMedium,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500),
                            ),
                            if (label != 'Dashboard' && label != 'Drivers')
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF)),
                          ],
                        ),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
            icon: Icon(Icons.menu_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary),
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
                const AppText('Welcome Admin',
                    style: AppTextStyle.labelMedium, color: Color(0xFF6B7280)),
              ],
            );
          }),
          const Spacer(),
          PopupMenuButton<String>(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  Text('Add New',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: Colors.white),
                ],
              ),
            ),
            onSelected: (value) {
              if (value == 'truck') {
                _showTruckFormDialog(context, isDark);
              } else if (value == 'driver') {
                _showUserFormDialog(context, isDark);
              } else if (value == 'vendor') {
                _showVendorFormDialog(context, isDark);
              } else if (value == 'customer') {
                _showCustomerFormDialog(context, isDark);
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
                value: 'vendor',
                child: Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Add Vendor'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'customer',
                child: Row(
                  children: [
                    Icon(Icons.apartment_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Add Customer'),
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
          InkWell(
            onTap: () {
              final session = Get.find<SessionService>();
              _showEditAdminProfileDialog(context, isDark, session);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Obx(() {
                final session = Get.find<SessionService>();
                final avatar = session.avatarUrl.value.isNotEmpty
                    ? session.avatarUrl.value
                    : 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop';
                final name = session.name.value.isNotEmpty
                    ? session.name.value
                    : 'Admin User';
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade200,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: corsSafeImageUrl(avatar),
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.person_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(name,
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.bold),
                        const AppText('Super Admin',
                            style: AppTextStyle.labelMedium,
                            color: Color(0xFF6B7280)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Dashboard: stats grid ----
  Widget _buildStatsGrid(bool isDark) {
    final stats = [
      (
        'TOTAL TRUCKS',
        '${controller.trucks.length}',
        Icons.local_shipping_rounded,
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
        () => controller.changeTabIndex(2)
      ),
      (
        'ASSIGNED TODAY',
        '${controller.assignedTrucks.length}',
        Icons.event_available_rounded,
        const Color(0xFFE0F2FE),
        const Color(0xFF0369A1),
        () => controller.changeTabIndex(2)
      ),
      (
        'IDLE TRUCKS',
        '${controller.idleTrucks.length}',
        Icons.pause_circle_rounded,
        const Color(0xFFFEF9C3),
        const Color(0xFFA16207),
        () => controller.changeTabIndex(2)
      ),
      (
        'BREAKDOWN',
        '${controller.problemTrucks.length}',
        Icons.build_rounded,
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        () => controller.changeTabIndex(2)
      ),
      (
        'ACTIVE TRIPS',
        '${controller.activeTripsCount}',
        Icons.my_location_rounded,
        const Color(0xFFF3E8FF),
        const Color(0xFF7E22CE),
        controller.openActiveDrivers
      ),
      (
        'COMPLETED',
        '${controller.completedTripsCount}',
        Icons.task_alt_rounded,
        const Color(0xFFE3FCEF),
        const Color(0xFF006644),
        () => controller.changeTabIndex(1)
      ),
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

  Widget _kanbanColumn(
      bool isDark, String title, int count, Color dot, List<Widget> cards,
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
                  style: AppTextStyle.labelMedium, textAlign: TextAlign.center),
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
      case 'LOAD_REJECTED':
        return ('Load Rejected', AppColors.error);
      case 'ACTIVE NOW':
        return ('Active', AppColors.success);
      case 'DELIVERY_REQUESTED':
        return ('Delivery Requested', AppColors.info);
      case 'DELIVERY_REJECTED':
        return ('Delivery Rejected', AppColors.error);
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    onPressed: () => Get.to(() => const AdminTripDetailsView(),
                        arguments: {'tripId': trip['id']}),
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
                      onPressed: () => _showSetDestinationDialog(context, trip),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      final match =
                          RegExp(r'trip\s+(\w+)', caseSensitive: false)
                              .firstMatch(body);
                      final matchId = match?.group(1);
                      if (matchId != null) {
                        final trip = controller.trips.firstWhereOrNull(
                            (trip) => trip['id'].toString() == matchId);
                        if (trip != null) {
                          controller.selectedTripId.value = matchId;
                          AppSnackBar.showSuccess(
                            title: 'Trip Selected',
                            message:
                                'Switched dashboard tracker to trip $matchId',
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
  /// Loud banner shown when Firestore is rejecting the dashboard's reads, so a
  /// rules/permissions problem doesn't masquerade as "no data yet".
  Widget _buildDataErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('Firebase se data load nahi ho raha',
                    style: AppTextStyle.bodyMedium,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold),
                const SizedBox(height: 2),
                AppText(message,
                    style: AppTextStyle.labelMedium, color: AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // If Firestore is rejecting reads, say so loudly — otherwise the
              // dashboard just shows 0 everywhere and looks "empty" rather
              // than broken.
              if (controller.dataError.value.isNotEmpty) ...[
                _buildDataErrorBanner(controller.dataError.value),
                const SizedBox(height: 16),
              ],
              _buildMockupStatsGrid(isDark),
              const SizedBox(height: 20),

              _buildBottomLayout(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockupStatsGrid(bool isDark) {
    final totalTrucks = controller.trucks.length;
    final assignedTrucks = controller.assignedTrucks.length;
    final totalDrivers = controller.allDrivers.length;
    final tripsToday = controller.trips.length;
    final completedCount = controller.completedTripsCount;

    Widget statCard({
      required String title,
      required String value,
      required String trend,
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
    }) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AppText(title,
                      style: AppTextStyle.labelMedium,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppText(value,
                style: AppTextStyle.headlineMedium,
                fontWeight: FontWeight.w800,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            AppText(trend,
                style: AppTextStyle.labelMedium,
                color: trend.contains('Critical') || trend.contains('--')
                    ? Colors.grey
                    : const Color(0xFF10B981),
                fontWeight: FontWeight.bold),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, cons) {
      final cols = cons.maxWidth >= 1100 ? 5 : (cons.maxWidth >= 700 ? 3 : 2);
      final w = (cons.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: w,
            child: statCard(
              title: 'TOTAL TRUCKS',
              value: '$totalTrucks',
              trend: '⬈ +8% from last month',
              icon: Icons.local_shipping_rounded,
              iconColor: const Color(0xFF1E40AF),
              iconBg: const Color(0xFFDBEAFE),
            ),
          ),
          SizedBox(
            width: w,
            child: statCard(
              title: 'ASSIGNED',
              value: '$assignedTrucks',
              trend: '⬈ +10% from last month',
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF047857),
              iconBg: const Color(0xFFD1FAE5),
            ),
          ),
          SizedBox(
            width: w,
            child: statCard(
              title: 'DRIVERS',
              value: '$totalDrivers',
              trend: '⬈ +5% from last month',
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF7E22CE),
              iconBg: const Color(0xFFF3E8FF),
            ),
          ),
          SizedBox(
            width: w,
            child: statCard(
              title: 'TRIPS TODAY',
              value: tripsToday.toString().padLeft(2, '0'),
              trend: '⬈ +14% from yesterday',
              icon: Icons.route_rounded,
              iconColor: const Color(0xFFEA580C),
              iconBg: const Color(0xFFFFEDD5),
            ),
          ),
          SizedBox(
            width: w,
            child: statCard(
              title: 'COMPLETED',
              value: completedCount.toString().padLeft(2, '0'),
              trend: '--',
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFE6F4EA),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMockupTodaysTripsOverview(BuildContext context, bool isDark) {
    return TruckAssignmentDashboard(
      isDark: isDark,
      onOpenTripForm: (passData) {
        _showTripFormDialog(context, isDark, prefilledPassData: passData);
      },
    );
  }

  Widget _buildMockupRecentAssignments(BuildContext context, bool isDark) {
    final assigned = controller.trucks
        .where((t) => (t['assignedTo'] ?? '').toString().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: AppText('Recent Assignments',
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.bold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (controller.trucks.isNotEmpty) {
                    _showAssignTruckDialog(context, controller.trucks.first);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Assign Truck',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color:
                              isDark ? Colors.white10 : Colors.grey.shade200)),
                ),
                children: const [
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: AppText('DRIVER DETAILS',
                          style: AppTextStyle.labelMedium,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: AppText('STATUS',
                          style: AppTextStyle.labelMedium,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: AppText('ASSIGNED DATE',
                          style: AppTextStyle.labelMedium,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              if (assigned.isEmpty)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: AppText('No recent assignments',
                          style: AppTextStyle.bodyMedium,
                          color: Colors.grey.shade400),
                    ),
                    const SizedBox(),
                    const SizedBox(),
                  ],
                ),
              ...assigned.take(3).map((a) {
                final driverPhone = a['assignedTo'].toString();
                final driverName = controller.driverNameFor(driverPhone);
                final trip = controller.trips.firstWhereOrNull((t) =>
                    t['driverPhone'].toString() == driverPhone &&
                    t['status'] != 'DELIVERED');

                final isEnRoute = trip != null &&
                    (trip['status'] == 'EN_ROUTE_VENDOR' ||
                        trip['status'] == 'ACTIVE NOW');

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade100)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              driverName.isNotEmpty
                                  ? driverName[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                    driverName.isNotEmpty ? driverName : 'DEEP',
                                    style: AppTextStyle.bodyMedium,
                                    fontWeight: FontWeight.bold),
                                AppText(a['truckNo'] ?? '',
                                    style: AppTextStyle.labelMedium,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEnRoute
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEnRoute ? 'ON WAY' : 'ASSIGNED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isEnRoute
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('11-07-2026',
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold),
                          AppText('08:30 AM',
                              style: AppTextStyle.labelMedium,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockupOperationsHub(BuildContext context, bool isDark) {
    final pending = controller.trucks.where((t) {
      final status = (t['inspectionStatus'] ?? '').toString();
      final hasDriver = (t['assignedTo'] ?? '').toString().isNotEmpty;
      if (!hasDriver) return false;

      // A submitted inspection is BLOCKING its driver (they sit on "Pending
      // Review" until the admin acts), so it must always surface — even when
      // that driver already has a trip running.
      if (status == 'inspected_pending_review') return true;

      // Not-yet-inspected trucks are only nagged about when the driver is free;
      // no point chasing an inspection for someone already out on a trip.
      if (status != 'pending') return false;
      final driverPhone = (t['assignedTo'] ?? '').toString();
      final hasActiveTrip = controller.trips.any((trip) =>
          (trip['driverPhone'] ?? '').toString() == driverPhone &&
          trip['status'] != 'DELIVERED' &&
          trip['status'] != 'CANCELLED');
      return !hasActiveTrip;
    }).toList();

    Widget actionButton(
        IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade100),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                AppText(label,
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              AppText('Operations Hub',
                  style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
            ],
          ),
          const SizedBox(height: 20),
          const AppText('QUICK ACTIONS',
              style: AppTextStyle.labelMedium,
              color: Colors.grey,
              fontWeight: FontWeight.bold),
          const SizedBox(height: 10),
          Row(
            children: [
              actionButton(
                  Icons.local_shipping_rounded,
                  'Add Truck',
                  const Color(0xFF10B981),
                  () => _showTruckFormDialog(context, isDark)),
              const SizedBox(width: 10),
              actionButton(
                  Icons.explore_rounded,
                  'Assign Trip',
                  const Color(0xFF3B82F6),
                  () => _assignTripGuarded(context, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              actionButton(
                  Icons.person_add_rounded,
                  'Add Driver',
                  const Color(0xFF8B5CF6),
                  () => _showUserFormDialog(context, isDark)),
              const SizedBox(width: 10),
              actionButton(Icons.description_rounded, 'Loading Pass',
                  const Color(0xFFF59E0B), () {
                final withPass = controller.trips
                    .where(
                        (t) => (t['loadingPassId'] ?? '').toString().isNotEmpty)
                    .toList();
                if (withPass.isNotEmpty) {
                  _showSetDestinationDialog(context, withPass.first);
                } else {
                  Get.snackbar('Loading Pass',
                      'No active trips with loading passes to approve right now.',
                      snackPosition: SnackPosition.BOTTOM);
                }
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText('PENDING INSPECTIONS',
                  style: AppTextStyle.labelMedium,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
              if (pending.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pending.length} Task',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBF2600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: AppText('No pending inspections',
                  style: AppTextStyle.bodyMedium, color: Colors.grey.shade400),
            )
          else
            ...pending.map((t) {
              final driverPhone = t['assignedTo'].toString();
              final driverName = controller.driverNameFor(driverPhone);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFFFFAF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFE4E6).withOpacity(0.5)),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => _showInspectionReviewDialog(context, isDark, t),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECE6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.playlist_add_check_rounded,
                        color: Color(0xFFBF2600), size: 18),
                  ),
                  title: Text(t['truckNo'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Driver: $driverName',
                      style: TextStyle(color: Colors.grey.shade600)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBottomLayout(BuildContext context, bool isDark) {
    return _buildMockupTodaysTripsOverview(context, isDark);
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
              final hr =
                  dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
              when =
                  "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
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
          border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE5EAE7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppText('Recent Notifications',
                        style: AppTextStyle.bodyLarge,
                        fontWeight: FontWeight.bold),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        AppPopup.showLoading(message: 'Resetting DB...');
                        await controller.clearDatabase();
                        AppPopup.hideLoading();
                        AppSnackBar.showSuccess(
                            title: 'Reset Success',
                            message: 'All active data reset to initial state.');
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          size: 14, color: AppColors.error),
                      label: const Text('Reset Data',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    if (Get.isRegistered<NotificationsController>()) {
                      const NotificationBell().open(Get.context!);
                    }
                  },
                  child: const AppText('View All',
                      style: AppTextStyle.labelMedium,
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 36,
                        color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const AppText('No new notifications',
                        style: AppTextStyle.bodyMedium, color: Colors.grey),
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
                              AppText(n['body'],
                                  style: AppTextStyle.bodyMedium,
                                  fontWeight: FontWeight.bold),
                              const SizedBox(height: 2),
                              AppText(n['date'],
                                  style: AppTextStyle.labelMedium,
                                  fontSize: 11,
                                  color: const Color(0xFF9CA3AF)),
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

  void _showInspectionReviewDialog(
      BuildContext context, bool isDark, Map<String, dynamic> truck) {
    final results = truck['inspectionResults'] as Map<dynamic, dynamic>? ?? {};
    final remarks = truck['inspectionRemarks']?.toString() ?? 'No remarks';
    final images = truck['inspectionImages'] as List<dynamic>? ?? [];
    final driverPhone = truck['assignedTo'].toString();
    final driverName = controller.driverNameFor(driverPhone);

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Review Inspection: ${truck['truckNo']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('Driver: $driverName',
                    style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                const Divider(height: 16),
                const AppText('Checklist Results:',
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold),
                const SizedBox(height: 6),
                ...results.entries.map((e) {
                  final isGood = e.value == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                            isGood
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: isGood ? AppColors.success : AppColors.error,
                            size: 16),
                        const SizedBox(width: 8),
                        AppText(e.key.toString(),
                            style: AppTextStyle.bodyMedium),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                AppText('Remarks: $remarks', style: AppTextStyle.bodyMedium),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const AppText('Inspection Photos:',
                      style: AppTextStyle.labelMedium,
                      fontWeight: FontWeight.bold),
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
                            child: CachedNetworkImage(
                              imageUrl: corsSafeImageUrl(images[i].toString()),
                              width: 240,
                              height: 180,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 240,
                                height: 180,
                                color: Colors.grey.shade100,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, size: 50),
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
  Widget _buildTripsTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: AppColors.primary,
        onPressed: () => _assignTripGuarded(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: _tripsHeader(context, isDark),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _tripsToolbar(context, isDark),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.loadData,
              color: AppColors.primary,
              child: Obx(() {
                final pageTrips = controller.pagedTrips;
                if (controller.filteredTrips.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.18),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.alt_route_rounded,
                                size: 56, color: AppColors.textHint),
                            SizedBox(height: 12),
                            AppText('No trips match your filters.',
                                style: AppTextStyle.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return LayoutBuilder(builder: (context, cons) {
                  const hPad = 20.0;
                  const spacing = 16.0;
                  final avail = cons.maxWidth - hPad * 2;

                  // Breakpoints: >=900px -> 3 cols, 580-899px -> 2 cols, <580px -> 1 col
                  int crossAxisCount;
                  if (avail >= 900) {
                    crossAxisCount = 3;
                  } else if (avail >= 580) {
                    crossAxisCount = 2;
                  } else {
                    crossAxisCount = 1;
                  }

                  final hasPendingActions = pageTrips.any((t) {
                    final s = (t['status'] ?? '').toString();
                    return s == 'LOAD_REQUESTED' ||
                        s == 'DELIVERY_REQUESTED' ||
                        s == 'LOAD_REJECTED' ||
                        s == 'DELIVERY_REJECTED';
                  });

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(hPad, 4, hPad, 40),
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: hasPendingActions ? 395 : 305,
                        ),
                        itemCount: pageTrips.length,
                        itemBuilder: (context, idx) {
                          final t = pageTrips[idx];
                          return FadeSlideIn(
                            key: ValueKey('trip-${t['id']}'),
                            delay: Duration(
                                milliseconds: (idx * 40).clamp(0, 320)),
                            child: _tripCard(context, isDark, t),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _tripsPagination(context, isDark),
                    ],
                  );
                });
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripsHeader(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final titleCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trips',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage all your trips and track deliveries',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Delete All Trips ─────────────────────────────────────────────
            Obx(() {
              if (controller.trips.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: OutlinedButton.icon(
                  onPressed: controller.deleteAllTrips,
                  icon: const Icon(Icons.delete_sweep_rounded,
                      size: 16, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Delete All',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFCA5A5),
                      width: 1.2,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                        : const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }),
            // ── New Trip ─────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => _assignTripGuarded(context, isDark),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New Trip',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleCol,
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleCol),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _tripsToolbar(BuildContext context, bool isDark) {
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tab segments (All | Today | En Route | Pending | Completed | Cancelled)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tripMockupFilterChip('All',
                        'All Trips (${controller.tripStatusCount("All")})'),
                    _tripMockupFilterChip('Today',
                        'Today (${controller.tripStatusCount("Today")})'),
                    _tripMockupFilterChip('En Route',
                        'En Route (${controller.tripStatusCount("En Route")})'),
                    _tripMockupFilterChip('Pending',
                        'Pending (${controller.tripStatusCount("Pending")})'),
                    _tripMockupFilterChip('Completed',
                        'Completed (${controller.tripStatusCount("Completed")})'),
                    _tripMockupFilterChip('Cancelled',
                        'Cancelled (${controller.tripStatusCount("Cancelled")})'),
                  ],
                )),
          ),
        ),

        // Driver selection, Date selection, Search, tune/clear filters.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Input
            SizedBox(
              width: 180,
              height: 38,
              child: TextField(
                controller: controller.tripSearchController,
                onChanged: controller.setTripSearch,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search trips...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Driver-wise Filter Dropdown
            Obx(() {
              final driversList = controller.availableTripDriverNames;
              final currentSelected = controller.tripDriverFilter.value;
              final displaySelected = driversList.contains(currentSelected)
                  ? currentSelected
                  : 'All Drivers';
              final isFiltered = displaySelected != 'All Drivers';

              return Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFiltered ? AppColors.primary : borderColor,
                    width: isFiltered ? 1.5 : 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: displaySelected,
                    isDense: true,
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: isFiltered
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isFiltered ? FontWeight.w600 : FontWeight.w500,
                      color: isFiltered
                          ? AppColors.primary
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: driversList.map((String driver) {
                      return DropdownMenuItem<String>(
                        value: driver,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              driver == 'All Drivers'
                                  ? Icons.badge_outlined
                                  : Icons.person_pin_rounded,
                              size: 14,
                              color: driver == displaySelected
                                  ? AppColors.primary
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(driver),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) controller.setTripDriverFilter(val);
                    },
                  ),
                ),
              );
            }),

            // Date Filter
            Obx(() {
              final d = controller.tripDateFilter.value;
              final isFiltered = d != null;
              final label = d == null
                  ? 'All Dates'
                  : '${d.day} ${_monthNames[d.month - 1]}, ${d.year}';
              return OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: d ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) controller.setTripDateFilter(picked);
                },
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: isFiltered
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w500,
                    color: isFiltered
                        ? AppColors.primary
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(
                    color: isFiltered ? AppColors.primary : borderColor,
                    width: isFiltered ? 1.5 : 1,
                  ),
                  minimumSize: const Size(0, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            }),

            // Reset Filter Action
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: IconButton(
                onPressed: controller.clearTripFilters,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                tooltip: 'Reset Filters',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tripMockupFilterChip(String filterVal, String displayLabel) {
    return Obx(() {
      final selected = controller.tripStatusFilter.value == filterVal;
      final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
      return GestureDetector(
        onTap: () => controller.setTripFilter(filterVal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.primary : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ]
                : null,
          ),
          child: Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
        ),
      );
    });
  }

  (String, Color, Color) _tripStatusStyle(String status, bool isActive) {
    const green = Color(0xFF15803D), greenBg = Color(0xFFDCFCE7);
    const amber = Color(0xFFD97706), amberBg = Color(0xFFFEF3C7);
    const blue = Color(0xFF2563EB), blueBg = Color(0xFFE0F2FE);
    const red = Color(0xFFDC2626), redBg = Color(0xFFFEE2E2);
    switch (status) {
      case 'PENDING':
        return ('PENDING', amberBg, amber);
      case 'ASSIGNED':
        return ('ACCEPTED', blueBg, blue);
      case 'EN_ROUTE_VENDOR':
      case 'ACTIVE NOW':
        return ('EN ROUTE', greenBg, green);
      case 'LOADING':
        return ('LOADING', amberBg, amber);
      case 'LOAD_REQUESTED':
        return ('LOAD REQUEST', amberBg, amber);
      case 'LOAD_REJECTED':
        return ('LOAD REJECTED', redBg, red);
      case 'DELIVERED':
        return ('COMPLETED', greenBg, green);
      case 'REJECTED':
        return ('CANCELLED', redBg, red);
      default:
        return (status.isEmpty ? 'TRIP' : status, greenBg, green);
    }
  }

  Widget _tripCard(
      BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final status = (trip['status'] ?? '').toString();
    final (statusLabel, statusBg, statusFg) =
        _tripStatusStyle(status, trip['isActive'] == true);
    final truckNo = (trip['truckNo'] ?? '-').toString();
    final tripId = (trip['id'] ?? '-').toString();
    final loadingPhotoUrl = (trip['loadingPhotoUrl'] ?? '').toString();
    final gatePassPhotoUrl = (trip['gatePassPhotoUrl'] ?? '').toString();
    final podUrl = (trip['podUrl'] ?? '').toString();
    final passGenTime = (trip['loadingPassGeneratedAt'] ?? '').toString();
    final date = (trip['date'] ?? '').toString();
    final passGenValue = passGenTime.isNotEmpty
        ? passGenTime
        : (date.isNotEmpty ? '$date 08:00 AM' : '-');
    final driverPhone = (trip['driverPhone'] ?? '').toString();
    final driver = controller.driverNameFor(driverPhone);
    final material = (trip['materialName'] ?? 'General Cargo').toString();
    final pickupCity = (trip['pickupCity'] ?? '').toString();
    final pickupLocation = (trip['pickupLocation'] ?? '').toString();
    final dropCity = (trip['dropCity'] ?? '').toString();
    final dropLocation =
        (trip['dropLocation'] ?? 'Destination pending').toString();
    final adminCtrl = Get.isRegistered<AdminHomeController>()
        ? Get.find<AdminHomeController>()
        : null;
    String avatarUrl = (trip['driverAvatar'] ??
            trip['driverPhoto'] ??
            trip['driverAvatarUrl'] ??
            trip['driverImage'] ??
            '')
        .toString()
        .trim();
    if (avatarUrl.isEmpty && adminCtrl != null) {
      if (driverPhone.isNotEmpty) {
        avatarUrl = adminCtrl.driverAvatarFor(driverPhone);
      }
      if (avatarUrl.isEmpty && driver.isNotEmpty) {
        avatarUrl = adminCtrl.driverAvatarFor(driver);
      }
    }
    final seqLabel = controller.tripSequenceLabel(trip);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Driver Avatar + Details & Status Badge ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: corsSafeImageUrl(avatarUrl.isNotEmpty
                        ? avatarUrl
                        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
                    fit: BoxFit.cover,
                    width: 34,
                    height: 34,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      driver.isNotEmpty ? driver : 'Unassigned',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            truckNo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (seqLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: seqLabel.contains('Queued')
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              seqLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: seqLabel.contains('Queued')
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Vertical Route Timeline Box ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical timeline line track
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 26,
                        color:
                            isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup Section
                      Text(
                        'PICKUP • ${date.isNotEmpty ? date : 'TODAY'}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        pickupCity.isNotEmpty
                            ? (pickupLocation.isNotEmpty
                                ? '$pickupCity, $pickupLocation'
                                : pickupCity)
                            : 'Rajkot Main Depot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Dropoff Section
                      const Text(
                        'DROP-OFF • EST. TIME TBD',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        dropCity.isNotEmpty
                            ? (dropLocation.isNotEmpty
                                ? '$dropCity, $dropLocation'
                                : dropCity)
                            : 'Destination pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dropCity.isNotEmpty
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B))
                              : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Key-Value Information Matrix (2x2) ───────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRIP ID',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '#$tripId',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MATERIAL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      material,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISTANCE / ETA',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Est. N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PASS GENERATED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      passGenValue,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Verification Photos & Direct Approve/Reject actions (for pending states)
          if (status == 'LOAD_REQUESTED' ||
              status == 'DELIVERY_REQUESTED' ||
              status == 'LOAD_REJECTED' ||
              status == 'DELIVERY_REJECTED') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (status == 'LOAD_REQUESTED' ||
                    status == 'LOAD_REJECTED') ...[
                  if (loadingPhotoUrl.isNotEmpty) ...[
                    _buildPhotoPreview(
                        context, loadingPhotoUrl, 'Loading Photo', isDark),
                    const SizedBox(width: 8),
                  ],
                  if (gatePassPhotoUrl.isNotEmpty) ...[
                    _buildPhotoPreview(
                        context, gatePassPhotoUrl, 'Gate Pass Photo', isDark),
                  ],
                ],
                if ((status == 'DELIVERY_REQUESTED' ||
                        status == 'DELIVERY_REJECTED') &&
                    podUrl.isNotEmpty) ...[
                  _buildPhotoPreview(context, podUrl, 'POD Proof', isDark),
                ],
              ],
            ),
            if (status == 'LOAD_REJECTED') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Rejected: ${trip['loadRejectReason'] ?? 'None'}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
            if (status == 'DELIVERY_REJECTED') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Rejected: ${trip['deliveryRejectReason'] ?? 'None'}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
            if (status == 'LOAD_REQUESTED') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showRejectLoadDialog(context, tripId, isDark),
                      icon: const Icon(Icons.close_rounded, size: 12),
                      label: const Text('Reject',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveLoadDirectly(tripId),
                      icon: const Icon(Icons.check_rounded, size: 12),
                      label: const Text('Approve',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'DELIVERY_REQUESTED') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showRejectDeliveryDialog(context, tripId, isDark),
                      icon: const Icon(Icons.close_rounded, size: 12),
                      label: const Text('Reject',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDeliveryDirectly(tripId),
                      icon: const Icon(Icons.check_rounded, size: 12),
                      label: const Text('Approve',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],

          const Spacer(),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 4),

          // ── Bottom Action Area: View Details + Edit + Options ─────────────
          Row(
            children: [
              Flexible(
                child: InkWell(
                  onTap: () => Get.to(() => const AdminTripDetailsView(),
                      arguments: {'tripId': tripId}),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'View Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit Trip',
                onPressed: () =>
                    _showTripFormDialog(context, isDark, editModeTrip: trip),
              ),
              _tripMenu(context, isDark, trip),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripMenu(
      BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final needsDest = (trip['dropCity'] ?? '').toString().trim().isEmpty &&
        trip['status'] != 'DELIVERED';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: Color(0xFF64748B)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (v) {
        switch (v) {
          case 'view':
            Get.to(() => const AdminTripDetailsView(),
                arguments: {'tripId': trip['id']});
            break;
          case 'edit':
            _showTripFormDialog(context, isDark, editModeTrip: trip);
            break;
          case 'dest':
            _showSetDestinationDialog(context, trip);
            break;
          case 'delete':
            controller.deleteTrip(trip['id']);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(children: [
            Icon(Icons.visibility_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 10),
            AppText('View Details', style: AppTextStyle.bodyMedium),
          ]),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 10),
            AppText('Edit Trip', style: AppTextStyle.bodyMedium),
          ]),
        ),
        if (needsDest)
          const PopupMenuItem(
            value: 'dest',
            child: Row(children: [
              Icon(Icons.add_location_alt_rounded,
                  size: 18, color: AppColors.tertiaryDark),
              SizedBox(width: 10),
              AppText('Set Destination', style: AppTextStyle.bodyMedium),
            ]),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.error),
            SizedBox(width: 10),
            AppText('Delete',
                style: AppTextStyle.bodyMedium, color: AppColors.error),
          ]),
        ),
      ],
    );
  }

  Widget _tripsPagination(BuildContext context, bool isDark) {
    return Obx(() {
      final total = controller.filteredTrips.length;
      final per = controller.tripsPerPage.value;
      final page = controller.tripPage.value;
      final start = total == 0 ? 0 : page * per + 1;
      final end = ((page + 1) * per).clamp(0, total);
      final pageCount = controller.tripPageCount;

      final pageButtons = <Widget>[];
      for (var i = 0; i < pageCount && i < 5; i++) {
        final selected = i == page;
        pageButtons.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => controller.goToTripPage(i),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ));
      }

      Widget navBtn(IconData icon, bool enabled, VoidCallback onTap) {
        return GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon,
                size: 16,
                color: enabled
                    ? (isDark ? Colors.white70 : const Color(0xFF64748B))
                    : AppColors.textHint),
          ),
        );
      }

      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          Text(
            'Showing $start to $end of $total trips',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              navBtn(Icons.chevron_left_rounded, page > 0,
                  () => controller.goToTripPage(page - 1)),
              const SizedBox(width: 4),
              ...pageButtons,
              const SizedBox(width: 4),
              navBtn(Icons.chevron_right_rounded, page < pageCount - 1,
                  () => controller.goToTripPage(page + 1)),
              const SizedBox(width: 10),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: per,
                    items: const [10, 20, 50]
                        .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text('$n / page',
                                style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.setTripsPerPage(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  // --- TAB 3: TRUCKS MANAGEMENT ---
  Widget _buildStatsCards(BuildContext context, bool isDark) {
    final totalVehicles = controller.trucks.length;
    final activeDeployments =
        controller.trucks.where((t) => t['status'] == 'En Route').length;
    final idleUnits = controller.trucks
        .where((t) => t['status'] == 'Idle' || (t['status'] ?? '').isEmpty)
        .length;
    final maintenanceReq = controller.trucks
        .where((t) => t['inspectionStatus'] == 'problem')
        .length;

    Widget statCard({
      required String title,
      required String value,
      required IconData icon,
      required Color iconColor,
      Widget? leadingIconBadge,
      String? badgeText,
      Color? badgeColor,
      Color? badgeBg,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (leadingIconBadge != null) ...[
                  leadingIconBadge,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: iconColor, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg ??
                          (badgeColor ?? const Color(0xFF16A34A))
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor ?? const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, cons) {
      const spacing = 12.0;
      int perRow = 4;
      if (cons.maxWidth < 560) {
        perRow = 1;
      } else if (cons.maxWidth < 880) {
        perRow = 2;
      }
      final cardWidth = (cons.maxWidth - spacing * (perRow - 1)) / perRow;

      final cards = [
        statCard(
          title: 'TOTAL VEHICLES',
          value: '$totalVehicles',
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF16A34A),
          leadingIconBadge: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFF16A34A), size: 14),
          ),
          badgeText: '↑ 2.4%',
          badgeColor: const Color(0xFF15803D),
          badgeBg: const Color(0xFFDCFCE7),
        ),
        statCard(
          title: 'ACTIVE DEPLOYMENTS',
          value: '$activeDeployments / $totalVehicles',
          icon: Icons.directions_car_filled_rounded,
          iconColor: const Color(0xFF16A34A),
        ),
        statCard(
          title: 'IDLE UNITS',
          value: '$idleUnits',
          icon: Icons.pause_circle_filled_rounded,
          iconColor: const Color(0xFF64748B),
        ),
        statCard(
          title: 'MAINTENANCE REQ',
          value: '$maintenanceReq',
          icon: Icons.build_circle_rounded,
          iconColor: const Color(0xFFDC2626),
          badgeText: '! Critical',
          badgeColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEE2E2),
        ),
      ];

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    });
  }

  Widget _buildMockupTruckCard(
      BuildContext context, bool isDark, Map<String, dynamic> truck) {
    final truckNo = (truck['truckNo'] ?? '').toString();
    final model =
        (truck['model'] ?? 'General Vehicle').toString().toUpperCase();
    final assignedTo = (truck['assignedTo'] ?? '').toString();
    final inspection = (truck['inspectionStatus'] ?? '').toString();
    final issue = (truck['inspectionIssue'] ?? '').toString();
    final status = (truck['status'] ?? 'Idle').toString();
    final truckType = (truck['type'] ?? '').toString();

    final isEnRoute = status == 'En Route';
    final hasProblem = inspection == 'problem';
    final needsReview = inspection == 'inspected_pending_review';

    String driverName = assignedTo;
    if (assignedTo.isNotEmpty) {
      final u = controller.users
          .firstWhereOrNull((u) => (u['phone'] ?? '') == assignedTo);
      if (u != null && (u['name'] ?? '').toString().isNotEmpty) {
        driverName = u['name'].toString();
      }
    }

    Color statusBg = const Color(0xFFF1F5F9);
    Color statusFg = const Color(0xFF475569);
    String statusLabel = '• IDLE';

    if (isEnRoute) {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF15803D);
      statusLabel = '• EN ROUTE';
    } else if (hasProblem || needsReview) {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
      statusLabel = '• INSPECTION';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasProblem
              ? const Color(0xFFFCA5A5)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Row 1: Vehicle No + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  truckNo,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          // Row 2: Type badge (e.g. 4W, 12W, 6W)
          if (truckType.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  truckType,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 2),

          // Row 3: Model Title
          Text(
            model,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Row 4: Operator Name / Unassigned
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 14,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  assignedTo.isEmpty ? 'Unassigned' : 'Op. $driverName',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: assignedTo.isEmpty
                        ? const Color(0xFF94A3B8)
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    fontStyle: assignedTo.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontWeight: assignedTo.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (hasProblem) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      issue.isNotEmpty ? issue : 'Diagnostics Required',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          Divider(
              height: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),

          // Bottom Action row: Edit, Delete, Assign / Reassign
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 15),
                color: const Color(0xFF64748B),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit Vehicle',
                onPressed: () =>
                    _showTruckFormDialog(context, isDark, editModeTruck: truck),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                color: const Color(0xFF64748B),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete Vehicle',
                onPressed: () => controller.deleteTruck(truckNo),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showAssignTruckDialog(context, truck),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assignedTo.isEmpty ? 'ASSIGN' : 'REASSIGN',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignTruckDialog(
      BuildContext context, Map<String, dynamic> truck) {
    final drivers = controller.allDrivers
        .where((d) => controller.isDriverCheckedIn(d))
        .toList();
    if (drivers.isEmpty) {
      AppSnackBar.showWarning(
          title: 'No Checked-In Drivers 🔴',
          message:
              'Koi driver abhi Checked-In (Available) nahi hai. Drivers ko app se check-in karne bole.');
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

          return LayoutBuilder(builder: (context, cons) {
            const hPad = 20.0;
            const spacing = 14.0;
            final avail = cons.maxWidth - hPad * 2;
            int crossAxisCount = 3;
            if (avail < 560) {
              crossAxisCount = 1;
            } else if (avail < 880) {
              crossAxisCount = 2;
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
              children: [
                // Header section
                LayoutBuilder(builder: (context, headerCons) {
                  final isNarrow = headerCons.maxWidth < 640;

                  final titleSection = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fleet Tracker Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Real-time status and deployment metrics for all ground units.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actionButtons = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.filter_list_rounded, size: 15),
                        label: const Text('Filter',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white70 : const Color(0xFF334155),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showTruckFormDialog(context, isDark),
                        icon: const Icon(Icons.add_rounded,
                            size: 16, color: Colors.white),
                        label: const Text('Register Vehicle',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 12),
                        actionButtons,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 12),
                      actionButtons,
                    ],
                  );
                }),
                const SizedBox(height: 16),

                // Stats Cards
                _buildStatsCards(context, isDark),
                const SizedBox(height: 20),

                // Vehicle Roster Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vehicle Roster',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Vehicles Grid List
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: 195,
                  ),
                  itemCount: controller.trucks.length,
                  itemBuilder: (context, idx) {
                    final truck = controller.trucks[idx];
                    return _buildMockupTruckCard(context, isDark, truck);
                  },
                ),
              ],
            );
          });
        }),
      ),
    );
  }

  // --- TAB 4: ROLES & USERS MANAGEMENT ---

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
                child: CachedNetworkImage(
                  imageUrl: corsSafeImageUrl(url),
                  fit: BoxFit.contain,
                  placeholder: (ctx, url) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  errorWidget: (ctx, url, err) => const Padding(
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
          final driversList = controller.allDrivers;
          if (driversList.isEmpty) {
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

          final width = MediaQuery.of(context).size.width;
          final isWide = width >= 900;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Delete All Drivers action bar ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.deleteAllDrivers,
                      icon: const Icon(Icons.delete_sweep_rounded,
                          size: 16, color: Colors.red),
                      label: const Text('Delete All Drivers',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              // Mockup Header Columns (only on web/wide screens)
              if (isWide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 4,
                        child: AppText('PERSONNEL PROFILE',
                            style: AppTextStyle.labelMedium,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Center(
                          child: AppText('CURRENT STATUS',
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: AppText('ASSIGNED HUB',
                            style: AppTextStyle.labelMedium,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Center(
                          child: AppText('COMPLIANCE CHECKS',
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 48), // Align with more options menu
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: driversList.length,
                  itemBuilder: (context, index) {
                    final user = driversList[index];
                    final isDriver = (user['role'] ?? 'driver') != 'admin';
                    final phone = (user['phone'] ?? '').toString();
                    final name = (user['name'] ?? '').toString();
                    final avatarUrl = (user['avatarUrl'] ?? '').toString();

                    // Initials for avatar fallback
                    String initials = 'DR';
                    if (name.isNotEmpty) {
                      final parts = name.split(' ');
                      if (parts.length > 1) {
                        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                      } else {
                        initials = name
                            .substring(
                                0, parts[0].length >= 2 ? 2 : parts[0].length)
                            .toUpperCase();
                      }
                    }

                    // Status details
                    final onLeave = controller.isOnLeave(user);
                    final available = controller.isDriverCheckedIn(user);

                    String statusText = 'OFF DUTY';
                    Color statusColor = const Color(0xFF6B7280);
                    Color statusBg = const Color(0xFFF1F5F9);
                    if (onLeave) {
                      statusText = 'ON LEAVE';
                      statusColor = const Color(0xFFD97706);
                      statusBg = const Color(0xFFFEF3C7);
                    } else if (available) {
                      statusText = 'AVAILABLE';
                      statusColor = const Color(0xFF047857);
                      statusBg = const Color(0xFFDCFCE7);
                    }

                    // Hub details representation (checked in address)
                    final address = (user['checkInAddress'] ?? '').toString();
                    final hubName =
                        address.isNotEmpty ? address : 'Main Terminal';
                    final hubId =
                        'ID: T-${phone.length >= 4 ? phone.substring(phone.length - 4) : "1000"}';

                    // Wide Layout
                    if (isWide) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.2 : 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Personnel Profile Column
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey.shade200,
                                        child: ClipOval(
                                          child: avatarUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: corsSafeImageUrl(
                                                      avatarUrl),
                                                  fit: BoxFit.cover,
                                                  width: 44,
                                                  height: 44,
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(
                                                          Icons.person_rounded,
                                                          size: 22),
                                                )
                                              : Container(
                                                  color: isDark
                                                      ? const Color(0xFF059669)
                                                          .withOpacity(0.2)
                                                      : const Color(0xFFD1FAE5),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    initials,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors
                                                              .green.shade200
                                                          : const Color(
                                                              0xFF047857),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: available
                                                ? Colors.green
                                                : Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white,
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(name,
                                            style: AppTextStyle.bodyLarge,
                                            fontWeight: FontWeight.bold,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_rounded,
                                                size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            AppText(phone,
                                                style: AppTextStyle.labelMedium,
                                                color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Current Status Column
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: AppText(statusText,
                                      style: AppTextStyle.labelMedium,
                                      color: statusColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // Assigned Hub Column
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(hubName,
                                      style: AppTextStyle.bodyMedium,
                                      fontWeight: FontWeight.bold,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  AppText(hubId,
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.grey),
                                ],
                              ),
                            ),

                            // Compliance Checks Column
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildComplianceCheckButton(
                                      context,
                                      'PHOTO',
                                      Icons.portrait_rounded,
                                      avatarUrl,
                                      '$name — Photo',
                                      isDark),
                                  const SizedBox(width: 8),
                                  _buildComplianceCheckButton(
                                      context,
                                      'LICENCE',
                                      Icons.credit_card_rounded,
                                      (user['drivingLicenceUrl'] ?? '')
                                          .toString(),
                                      '$name — Licence',
                                      isDark),
                                  const SizedBox(width: 8),
                                  _buildComplianceCheckButton(
                                      context,
                                      'HEAVY',
                                      Icons.local_shipping_rounded,
                                      (user['heavyLicenceUrl'] ?? '')
                                          .toString(),
                                      '$name — Heavy Vehicle Licence',
                                      isDark),
                                ],
                              ),
                            ),

                            // Actions Column
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: AppColors.textSecondary),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  controller.deleteUser(phone);
                                } else if (value == 'leave') {
                                  controller.setDriverOnLeave(phone, true);
                                } else if (value == 'unleave') {
                                  controller.setDriverOnLeave(phone, false);
                                } else if (value == 'admin' ||
                                    value == 'driver') {
                                  if (value != user['role']) {
                                    controller.editUserRole(phone, value);
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
                                              ? Icons
                                                  .admin_panel_settings_rounded
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
                                    value: onLeave ? 'unleave' : 'leave',
                                    child: Row(
                                      children: [
                                        Icon(
                                            onLeave
                                                ? Icons.event_available_rounded
                                                : Icons.beach_access_rounded,
                                            size: 18,
                                            color: AppColors.tertiaryDark),
                                        const SizedBox(width: 10),
                                        AppText(
                                            onLeave
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
                      );
                    }

                    // Mobile Layout (fallback)
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
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey.shade200,
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: corsSafeImageUrl(avatarUrl),
                                          fit: BoxFit.cover,
                                          width: 44,
                                          height: 44,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.person_rounded,
                                                  size: 22),
                                        )
                                      : Container(
                                          color: const Color(0xFFD1FAE5),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                                fontSize: 14),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(name,
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold),
                                    const SizedBox(height: 2),
                                    AppText(phone,
                                        style: AppTextStyle.labelMedium,
                                        color: Colors.grey),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: AppText(statusText,
                                    style: AppTextStyle.labelMedium,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AppText('HUB',
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.grey),
                                  const SizedBox(height: 2),
                                  AppText(hubName,
                                      style: AppTextStyle.bodyMedium,
                                      fontWeight: FontWeight.bold),
                                ],
                              ),
                              Row(
                                children: [
                                  _buildComplianceCheckButton(
                                      context,
                                      'PHOTO',
                                      Icons.portrait_rounded,
                                      avatarUrl,
                                      '$name — Photo',
                                      isDark),
                                  const SizedBox(width: 6),
                                  _buildComplianceCheckButton(
                                      context,
                                      'LICENCE',
                                      Icons.credit_card_rounded,
                                      (user['drivingLicenceUrl'] ?? '')
                                          .toString(),
                                      '$name — Licence',
                                      isDark),
                                  const SizedBox(width: 6),
                                  _buildComplianceCheckButton(
                                      context,
                                      'HEAVY',
                                      Icons.local_shipping_rounded,
                                      (user['heavyLicenceUrl'] ?? '')
                                          .toString(),
                                      '$name — Heavy Vehicle Licence',
                                      isDark),
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Mockup Pagination Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                        'Showing 1-${driversList.length} of ${driversList.length} drivers',
                        style: AppTextStyle.bodyMedium,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_left_rounded,
                              size: 20),
                          onPressed: () {},
                          style: IconButton.styleFrom(
                            side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('1',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('2',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('3',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_right_rounded,
                              size: 20),
                          onPressed: () {},
                          style: IconButton.styleFrom(
                            side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildComplianceCheckButton(BuildContext context, String label,
      IconData icon, String url, String title, bool isDark) {
    final present = url.isNotEmpty && url.startsWith('http');
    final activeBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF);
    final activeIconColor =
        isDark ? AppColors.primary : const Color(0xFF1E40AF);
    final inactiveBg =
        isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9);
    final inactiveIconColor = isDark ? Colors.white30 : const Color(0xFF9CA3AF);

    Widget card = Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: present ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              present ? activeIconColor.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: present ? activeIconColor : inactiveIconColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: present ? activeIconColor : inactiveIconColor,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (present) {
      return InkWell(
        onTap: () => _showImageViewer(context, url, title),
        borderRadius: BorderRadius.circular(8),
        child: card,
      );
    }
    return card;
  }

  // --- TAB 5: VENDORS (predefined pickup sources) ---
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

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 165,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: controller.vendors.length,
            itemBuilder: (context, index) {
              return _buildCompactVendorCard(
                  context, controller.vendors[index], isDark);
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

  Widget _buildCompactVendorCard(
      BuildContext context, Map<String, dynamic> v, bool isDark) {
    final name = (v['name'] ?? 'Vendor').toString();
    final phone = (v['phone'] ?? '').toString();
    final siteName = (v['siteName'] ?? '').toString();
    final loc = (v['pickupLocation'] ?? v['location'] ?? '').toString();
    final cityDistrict = [
      (v['city'] ?? '').toString(),
      (v['district'] ?? '').toString()
    ].where((s) => s.isNotEmpty).join(', ');
    final items = _extractVendorItems(v);
    final vendorId = (v['id'] ?? '').toString();
    final displayId =
        'V-${vendorId.length >= 4 ? vendorId.substring(vendorId.length - 4) : "100"}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            name,
                            style: AppTextStyle.bodyLarge,
                            fontWeight: FontWeight.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AppText(
                            displayId,
                            style: AppTextStyle.labelMedium,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          AppText(phone,
                              style: AppTextStyle.labelMedium,
                              color: Colors.grey),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textSecondary, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showVendorFormDialog(context, isDark, editVendor: v);
                  } else if (value == 'delete') {
                    controller.deleteVendor((v['id'] ?? '').toString(),
                        name: name);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        AppText('Edit', style: AppTextStyle.bodyMedium),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
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
          const Divider(height: 10, thickness: 0.8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AppText(
                            siteName.isNotEmpty ? siteName : 'Pickup Location',
                            style: AppTextStyle.labelMedium,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      loc.isNotEmpty
                          ? loc
                          : (cityDistrict.isNotEmpty
                              ? cityDistrict
                              : 'Address pending'),
                      style: AppTextStyle.labelMedium,
                      color: Colors.grey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: items.take(2).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_rounded,
                                size: 11, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: AppText(
                                item,
                                style: AppTextStyle.labelMedium,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()
                      ..addAll(items.length > 2
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: AppText(
                                  '+${items.length - 2}',
                                  style: AppTextStyle.labelMedium,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ]
                          : []),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 7: CUSTOMERS (delivery destinations) ---
  Widget _buildCustomersTab(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          if (controller.customers.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.apartment_rounded,
                          size: 60, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const AppText('No customers yet. Tap "+" to add one.',
                          style: AppTextStyle.bodyLarge),
                      const SizedBox(height: 4),
                      const AppText(
                          'Customer ek baar add karein, phir delivery destination me select karein.',
                          style: AppTextStyle.labelMedium,
                          color: AppColors.textHint),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showCustomerFormDialog(context, isDark),
                        icon:
                            const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text('Add Customer',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return LayoutBuilder(builder: (context, cons) {
            const hPad = 16.0;
            final avail = cons.maxWidth - hPad * 2;
            int crossAxisCount = 3;
            if (avail < 600) {
              crossAxisCount = 1;
            } else if (avail < 950) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisExtent: 156,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: controller.customers.length,
              itemBuilder: (context, index) {
                return _buildCompactCustomerCard(
                    context, controller.customers[index], isDark);
              },
            );
          });
        }),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: AppColors.primary,
        onPressed: () => _showCustomerFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCompactCustomerCard(
      BuildContext context, Map<String, dynamic> c, bool isDark) {
    final name = (c['name'] ?? 'Customer').toString();
    final phone = (c['phone'] ?? '').toString();
    final siteName = (c['siteName'] ?? c['customerSite'] ?? '').toString();
    final loc = (c['location'] ?? c['address'] ?? '').toString();
    final cityDistrict = [
      (c['city'] ?? '').toString(),
      (c['district'] ?? '').toString()
    ].where((s) => s.isNotEmpty).join(', ');
    final custId = (c['id'] ?? '').toString();
    final displayId =
        'C-${custId.length >= 4 ? custId.substring(custId.length - 4) : "100"}';
    final fullAddress = loc.isNotEmpty
        ? loc
        : (cityDistrict.isNotEmpty ? cityDistrict : 'Address pending');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Row 1: Icon + Name & Site + ID & Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayId,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (siteName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.factory_rounded,
                              size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              siteName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Color(0xFF94A3B8), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showCustomerFormDialog(context, isDark, editCustomer: c);
                  } else if (value == 'delete') {
                    controller.deleteCustomer((c['id'] ?? '').toString(),
                        name: name);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          Divider(
              height: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),

          // Row 2: Delivery Location Header + Phone Chip
          Row(
            children: [
              const Icon(Icons.pin_drop_rounded,
                  size: 12.5, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text(
                'Delivery Location',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const Spacer(),
              if (phone.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 11, color: Color(0xFF15803D)),
                      const SizedBox(width: 3),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Row 3: Full Width Address (up to 3 lines without clipping)
          Text(
            fullAddress,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- POPUP DIALOG FORM HELPERS ---

  // 1. ADD / EDIT TRIP DIALOG

  /// Set the drop destination while the truck is loading — the driver sees it
  /// only after the load is approved.
  void _showSetDestinationDialog(
      BuildContext context, Map<String, dynamic> trip) {
    final formKey = GlobalKey<FormState>();
    final truckNo = (trip['truckNo'] ?? '').toString();
    final tripId = (trip['id'] ?? '').toString();

    final customerNameCtrl =
        TextEditingController(text: (trip['dropCity'] ?? '').toString());
    final customerSiteCtrl = TextEditingController(
        text: (trip['customerSite'] ?? trip['siteName'] ?? '').toString());
    final customerLocCtrl = TextEditingController(
        text: (trip['dropLocation'] ?? trip['location'] ?? '').toString());
    final detailsCtrl = TextEditingController();
    TextEditingController? siteTextController;
    TextEditingController? locTextController;

    final dbCustomers = controller.customers
        .map((c) => (c['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final customersList = dbCustomers.isNotEmpty
        ? dbCustomers
        : [
            "Tata Motors",
            "Mahindra Log",
            "L&T Construction",
            "Reliance Industries",
            "Adani Power"
          ];

    final dbSites = controller.customers
        .map(
            (c) => (c['siteName'] ?? c['customerSite'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final sitesList = dbSites.isNotEmpty
        ? dbSites
        : [
            "Pune Plant",
            "Chennai GIDC Site",
            "Kolkata Port Terminal",
            "Delhi Central Hub",
            "Nagpur Depot"
          ];

    final dbLocations = controller.customers
        .map((c) => (c['location'] ?? c['address'] ?? c['city'] ?? '')
            .toString()
            .trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    final locationsList = dbLocations.isNotEmpty
        ? dbLocations
        : [
            "Pune, Maharashtra",
            "Chennai, Tamil Nadu",
            "Kolkata, West Bengal",
            "Delhi NCR",
            "Nagpur, Maharashtra"
          ];

    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_location_alt_rounded,
                color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Destination Setup: $truckNo',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'Step 2: Enter destination details. "Save & Next" will launch the Create Trip wizard.',
                    style: AppTextStyle.labelMedium,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),

                  // 1. Customer Name Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: customerNameCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final currentDbNames = controller.customers
                          .map((c) => (c['name'] ?? '').toString().trim())
                          .where((n) => n.isNotEmpty)
                          .toList();
                      final currentCustomersList = currentDbNames.isNotEmpty
                          ? currentDbNames
                          : customersList;

                      if (textEditingValue.text.isEmpty) {
                        return currentCustomersList;
                      }
                      return currentCustomersList.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      textEditingController.addListener(() {
                        customerNameCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon:
                              const Icon(Icons.business_rounded, size: 18),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter customer name'
                                : null,
                      );
                    },
                    onSelected: (String selection) {
                      customerNameCtrl.text = selection;
                      final foundCust = controller.customers.firstWhereOrNull(
                          (c) =>
                              (c['name'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase() ==
                              selection.trim().toLowerCase());
                      if (foundCust != null) {
                        final site = (foundCust['siteName'] ??
                                foundCust['customerSite'] ??
                                '')
                            .toString()
                            .trim();
                        final loc = (foundCust['location'] ??
                                foundCust['address'] ??
                                foundCust['city'] ??
                                '')
                            .toString()
                            .trim();
                        if (site.isNotEmpty) {
                          customerSiteCtrl.text = site;
                          if (siteTextController != null) {
                            siteTextController!.text = site;
                          }
                        }
                        if (loc.isNotEmpty) {
                          customerLocCtrl.text = loc;
                          if (locTextController != null) {
                            locTextController!.text = loc;
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Customer Site Name Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: customerSiteCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final currentDbSites = controller.customers
                          .map((c) => (c['siteName'] ?? c['customerSite'] ?? '')
                              .toString()
                              .trim())
                          .where((s) => s.isNotEmpty)
                          .toSet()
                          .toList();
                      final currentSitesList = currentDbSites.isNotEmpty
                          ? currentDbSites
                          : sitesList;

                      if (textEditingValue.text.isEmpty) {
                        return currentSitesList;
                      }
                      return currentSitesList.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      siteTextController = textEditingController;
                      textEditingController.addListener(() {
                        customerSiteCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Customer Site Name',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon:
                              const Icon(Icons.factory_rounded, size: 18),
                        ),
                      );
                    },
                    onSelected: (String selection) {
                      customerSiteCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Customer Location / Address Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: customerLocCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final currentDbLocs = controller.customers
                          .map((c) =>
                              (c['location'] ?? c['address'] ?? c['city'] ?? '')
                                  .toString()
                                  .trim())
                          .where((l) => l.isNotEmpty)
                          .toSet()
                          .toList();
                      final currentLocsList = currentDbLocs.isNotEmpty
                          ? currentDbLocs
                          : locationsList;

                      if (textEditingValue.text.isEmpty) {
                        return currentLocsList;
                      }
                      return currentLocsList.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      locTextController = textEditingController;
                      textEditingController.addListener(() {
                        customerLocCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Delivery Address / Location',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon:
                              const Icon(Icons.pin_drop_rounded, size: 18),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter delivery location'
                                : null,
                      );
                    },
                    onSelected: (String selection) {
                      customerLocCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Additional destination details
                  TextFormField(
                    controller: detailsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Additional Destination Details',
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon:
                          const Icon(Icons.description_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final siteVal = customerSiteCtrl.text.trim();
              final locVal = customerLocCtrl.text.trim();
              final combinedSite = (siteVal.isNotEmpty && locVal.isNotEmpty)
                  ? '$siteVal ($locVal)'
                  : (siteVal.isNotEmpty ? siteVal : locVal);

              final data = {
                'customerName': customerNameCtrl.text.trim(),
                'customerSite': combinedSite,
                'siteName': siteVal,
                'customerLocation': locVal,
                'additionalDetails': detailsCtrl.text.trim(),
              };
              Get.back();
              AppPopup.showLoading(message: 'Saving Destination...');
              try {
                // Update Firestore for trip
                await controller.setDestination(
                    tripId, data['customerName']!, combinedSite);

                // Update active truck config if truckNo is valid
                if (truckNo.isNotEmpty && truckNo != '-') {
                  await Get.find<FirebaseService>()
                      .saveDestinationSetup(truckNo, data);
                }
                AppPopup.hideLoading();
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString());
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
      {Map<String, dynamic>? editModeTrip,
      Map<String, dynamic>? prefilledPassData}) {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: editModeTrip?['id'] ?? '');
    final pickupCityCtrl =
        TextEditingController(text: editModeTrip?['pickupCity'] ?? '');
    final pickupLocCtrl =
        TextEditingController(text: editModeTrip?['pickupLocation'] ?? '');
    final dropCityCtrl = TextEditingController(
        text:
            editModeTrip?['dropCity'] ?? prefilledPassData?['dropCity'] ?? '');
    final dropLocCtrl = TextEditingController(
        text: editModeTrip?['dropLocation'] ??
            prefilledPassData?['dropLocation'] ??
            '');
    final dateCtrl = TextEditingController(text: editModeTrip?['date'] ?? '');
    // Vendor / material details
    final vendorNameCtrl = TextEditingController(
        text: editModeTrip?['vendorName'] ??
            prefilledPassData?['vendorName'] ??
            '');
    final vendorLocCtrl = TextEditingController(
        text: editModeTrip?['vendorLocation'] ??
            prefilledPassData?['vendorLocation'] ??
            '');
    final materialCtrl = TextEditingController(
        text: editModeTrip?['materialName'] ??
            prefilledPassData?['itemName'] ??
            '');
    final passHolderCtrl =
        TextEditingController(text: editModeTrip?['passHolderName'] ?? '');
    final royaltyCtrl = TextEditingController(
        text: editModeTrip?['royaltyName'] ??
            prefilledPassData?['royaltyName'] ??
            '');
    final autoGeneratedPassId =
        (10000000 + Random().nextInt(90000000)).toString();
    final existingPassId = (editModeTrip?['loadingPassId'] ??
            prefilledPassData?['loadingPassId'] ??
            '')
        .toString()
        .trim();
    final loadingPassCtrl = TextEditingController(
        text: existingPassId.isNotEmpty ? existingPassId : autoGeneratedPassId);
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

    final availableDrivers = controller.allDrivers
        .where((u) {
          // On-leave or off-duty drivers can't be assigned trips.
          if (controller.isOnLeave(u)) return false;
          if (!controller.isDriverCheckedIn(u)) return false;
          final phone = u['phone'] as String?;
          if (phone == null || phone.isEmpty) return false;

          // Find the truck assigned to this driver phone
          final truck = controller.trucks
              .firstWhereOrNull((t) => t['assignedTo'] == phone);
          if (truck == null) return false;

          // Check if inspection is complete ('ready')
          return truck['inspectionStatus'] == 'ready';
        })
        .map((u) => u['phone'] as String)
        .toList();

    if (availableDrivers.isEmpty) {
      availableDrivers.add('+919876543210');
    }
    String selectedDriver = editModeTrip?['driverPhone'] ??
        prefilledPassData?['driverPhone'] ??
        availableDrivers.first;
    if (!availableDrivers.contains(selectedDriver)) {
      availableDrivers.add(selectedDriver);
    }

    final initialTruck = controller.trucks.firstWhereOrNull(
        (t) => t['assignedTo'] == selectedDriver)?['truckNo'] as String?;
    String selectedTruck = prefilledPassData?['truckNo'] ??
        initialTruck ??
        editModeTrip?['truckNo'] ??
        'MH-12-BV-0045';

    final availableTrucks =
        controller.trucks.map((t) => t['truckNo'] as String).toList();
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
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.4),
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
                                  ...controller.vendors
                                      .map((v) => DropdownMenuItem(
                                            value: (v['id'] ?? '').toString(),
                                            child: Text(
                                              (v['name'] ?? 'Vendor')
                                                  .toString(),
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
                                  final loc = (v['pickupLocation'] ??
                                          v['location'] ??
                                          '')
                                      .toString();
                                  vendorNameCtrl.text =
                                      (v['name'] ?? '').toString();
                                  vendorLocCtrl.text = loc;
                                  pickupLocCtrl.text = loc;
                                  pickupCityCtrl.text =
                                      (v['city'] ?? '').toString();
                                  pickupDistrictCtrl.text =
                                      (v['district'] ?? '').toString();
                                  final items = _extractVendorItems(v);
                                  if (items.length == 1) {
                                    materialCtrl.text = items.first;
                                  } else {
                                    materialCtrl.clear();
                                  }
                                  if (v['latitude'] != null) {
                                    pickupLatCtrl.text =
                                        v['latitude'].toString();
                                  }
                                  if (v['longitude'] != null) {
                                    pickupLngCtrl.text =
                                        v['longitude'].toString();
                                  }
                                },
                                // Vendor is required for new trips; legacy trips
                                // being edited may predate the vendor list.
                                validator: (v) {
                                  if (editModeTrip != null) return null;
                                  return (v == null ||
                                          v.isEmpty ||
                                          v == '__add__')
                                      ? 'Vendor select karein'
                                      : null;
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          StatefulBuilder(builder: (ctx, setSB) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: selectedTruck,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign Truck',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.local_shipping_rounded),
                                    helperText:
                                        'Truck is automatically set based on driver selection.',
                                  ),
                                  items: availableTrucks
                                      .map((t) => DropdownMenuItem(
                                          value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: null, // Disabled: read-only
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedDriver,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign Driver',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_rounded),
                                    helperText:
                                        'Only showing drivers with completed inspections.',
                                  ),
                                  items: availableDrivers.map((d) {
                                    final name = controller.users.firstWhere(
                                        (u) => u['phone'] == d,
                                        orElse: () => {'name': d})['name'];
                                    final activeCount =
                                        controller.driverActiveTripCount(d);
                                    final suffix = activeCount > 0
                                        ? ' ($activeCount active trip${activeCount > 1 ? 's' : ''})'
                                        : '';
                                    return DropdownMenuItem(
                                        value: d,
                                        child: Text('$name ($d)$suffix'));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSB(() {
                                        selectedDriver = val;
                                        final matchedTruck = controller.trucks
                                            .firstWhereOrNull(
                                                (t) => t['assignedTo'] == val);
                                        if (matchedTruck != null) {
                                          final truckNo =
                                              matchedTruck['truckNo'] as String;
                                          if (!availableTrucks
                                              .contains(truckNo)) {
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
                          }),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedTabType,
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
                          StatefulBuilder(
                            builder: (ctx, setMatState) {
                              final v = controller.vendors.firstWhereOrNull(
                                  (e) => e['id'] == selectedVendorId);
                              final items = _extractVendorItems(v);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: materialCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Material Name',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.category_rounded),
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Field required' : null,
                                  ),
                                  if (items.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          const AppText('Vendor Items: ',
                                              style: AppTextStyle.labelMedium,
                                              color: AppColors.textHint),
                                          ...items.map((item) {
                                            final isSelected = materialCtrl.text
                                                    .trim()
                                                    .toLowerCase() ==
                                                item.toLowerCase();
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 6),
                                              child: ChoiceChip(
                                                label: Text(item,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight
                                                                .normal)),
                                                selected: isSelected,
                                                onSelected: (selected) {
                                                  if (selected) {
                                                    setMatState(() {
                                                      materialCtrl.text = item;
                                                    });
                                                  }
                                                },
                                                selectedColor: isDark
                                                    ? const Color(0xFF3B82F6)
                                                        .withValues(alpha: 0.3)
                                                    : const Color(0xFFDBEAFE),
                                                backgroundColor: isDark
                                                    ? Colors.white10
                                                    : const Color(0xFFF1F5F9),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: royaltyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Royalty Name (optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.workspace_premium_rounded),
                            ),
                            validator: (v) => null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: loadingPassCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              labelText: 'Loading Pass ID (Auto-generated)',
                              helperText:
                                  'Auto-generated 8-digit pass ID (optional to change)',
                              border: OutlineInputBorder(),
                              prefixIcon:
                                  Icon(Icons.confirmation_number_rounded),
                              counterText: '',
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isNotEmpty &&
                                  !RegExp(r'^\d{8}$').hasMatch(s)) {
                                return 'Must be 8 digits if modified';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: dropCityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Drop City (optional)',
                              helperText: 'Loading ke time set hoga',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
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
                                if (!context.mounted) return;
                                final selectedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (selectedTime != null) {
                                  dateCtrl.text = formatDateTime(
                                      selectedDate, selectedTime);
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
                                      'vendorLocation':
                                          vendorLocCtrl.text.trim(),
                                      'materialName': materialCtrl.text.trim(),
                                      'passHolderName':
                                          passHolderCtrl.text.trim(),
                                      'royaltyName':
                                          royaltyCtrl.text.trim().isNotEmpty
                                              ? royaltyCtrl.text.trim()
                                              : 'N/A',
                                      'loadingPassId':
                                          loadingPassCtrl.text.trim().isNotEmpty
                                              ? loadingPassCtrl.text.trim()
                                              : autoGeneratedPassId,
                                      'loadingPassGeneratedAt': ((editModeTrip?[
                                                      'loadingPassId'] ??
                                                  '') ==
                                              loadingPassCtrl.text.trim())
                                          ? (editModeTrip?[
                                                  'loadingPassGeneratedAt'] ??
                                              '')
                                          : (loadingPassCtrl.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? _formatCurrentDateTime()
                                              : ''),
                                      'pickupDistrict':
                                          pickupDistrictCtrl.text.trim(),
                                      'pickupCity': pickupCityCtrl.text.trim(),
                                      'pickupLocation':
                                          pickupLocCtrl.text.trim(),
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
                                          editModeTrip?['currentMilestone'] ??
                                              0,
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

  static List<String> _extractVendorItems(Map<String, dynamic>? v) {
    if (v == null) return [];
    if (v['items'] is List) {
      final list = (v['items'] as List)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    final itemName = (v['itemName'] ?? '').toString().trim();
    if (itemName.isNotEmpty) {
      if (itemName.contains(',')) {
        return itemName
            .split(',')
            .map((e) => e.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [itemName];
    }
    return [];
  }

  /// Create/edit a predefined vendor (minimal location details). Once saved,
  /// admins just pick it in the trip form and its pickup info auto-fills.
  void _showVendorFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editVendor}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: editVendor?['name'] ?? '');
    final siteNameCtrl =
        TextEditingController(text: editVendor?['siteName'] ?? '');
    final phoneCtrl = TextEditingController(text: editVendor?['phone'] ?? '');
    final locCtrl = TextEditingController(
        text: (editVendor?['pickupLocation'] ?? editVendor?['location'] ?? '')
            .toString());
    final cityCtrl = TextEditingController(text: editVendor?['city'] ?? '');
    final districtCtrl =
        TextEditingController(text: editVendor?['district'] ?? '');

    final List<String> vendorItems = _extractVendorItems(editVendor);
    final addItemCtrl = TextEditingController();

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
                            controller: siteNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vendor Site Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.factory_rounded),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          StatefulBuilder(
                            builder: (itemCtx, setItemState) {
                              void addItem() {
                                final text = addItemCtrl.text.trim();
                                if (text.isNotEmpty) {
                                  if (!vendorItems.contains(text)) {
                                    setItemState(() {
                                      vendorItems.add(text);
                                      addItemCtrl.clear();
                                    });
                                  } else {
                                    addItemCtrl.clear();
                                  }
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: addItemCtrl,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Items / Materials Available',
                                            hintText:
                                                'e.g. Fly Ash, Cement, Coal',
                                            border: const OutlineInputBorder(),
                                            prefixIcon: const Icon(
                                                Icons.category_rounded),
                                            suffixIcon: IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_rounded,
                                                  color: AppColors.primary),
                                              onPressed: addItem,
                                            ),
                                          ),
                                          onFieldSubmitted: (_) => addItem(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (vendorItems.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.only(left: 4, bottom: 4),
                                      child: AppText(
                                        'Multiple items add kar sakte hain (Enter key ya + icon se add karein)',
                                        style: AppTextStyle.labelMedium,
                                        color: AppColors.textHint,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: vendorItems.map((item) {
                                        return InputChip(
                                          avatar: const Icon(
                                              Icons.inventory_2_rounded,
                                              size: 14,
                                              color: Color(0xFF2563EB)),
                                          label: Text(item,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87)),
                                          backgroundColor: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFEFF6FF),
                                          deleteIcon: const Icon(
                                              Icons.cancel_rounded,
                                              size: 16,
                                              color: Colors.redAccent),
                                          onDeleted: () {
                                            setItemState(() {
                                              vendorItems.remove(item);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: locCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full Address',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin_drop_rounded),
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
                                    labelText: 'City (optional)',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.location_city_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: districtCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'District (optional)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.map_rounded),
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
                                onPressed: () => Navigator.of(sheetCtx).pop(),
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
                                  final finalItems =
                                      List<String>.from(vendorItems);
                                  final pendingText = addItemCtrl.text.trim();
                                  if (pendingText.isNotEmpty &&
                                      !finalItems.contains(pendingText)) {
                                    finalItems.add(pendingText);
                                  }
                                  if (finalItems.isEmpty) {
                                    AppSnackBar.showError(
                                        title: 'Error',
                                        message:
                                            'Vendor me kam se kam 1 item add karein');
                                    return;
                                  }
                                  final data = <String, dynamic>{
                                    if (editVendor?['id'] != null)
                                      'id': editVendor!['id'],
                                    'name': nameCtrl.text.trim(),
                                    'siteName': siteNameCtrl.text.trim(),
                                    'items': finalItems,
                                    'itemName': finalItems.join(', '),
                                    'phone': phoneCtrl.text.trim(),
                                    'pickupLocation': locCtrl.text.trim(),
                                    'location': locCtrl.text.trim(),
                                    'city': cityCtrl.text.trim(),
                                    'district': districtCtrl.text.trim(),
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

  // 1c. ADD / EDIT CUSTOMER DIALOG
  void _showCustomerFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editCustomer}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: editCustomer?['name'] ?? '');
    final siteNameCtrl = TextEditingController(
        text: (editCustomer?['siteName'] ?? editCustomer?['customerSite'] ?? '')
            .toString());
    final phoneCtrl = TextEditingController(text: editCustomer?['phone'] ?? '');
    final locCtrl = TextEditingController(
        text: (editCustomer?['location'] ?? editCustomer?['address'] ?? '')
            .toString());
    final cityCtrl = TextEditingController(text: editCustomer?['city'] ?? '');
    final districtCtrl =
        TextEditingController(text: editCustomer?['district'] ?? '');

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
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      editCustomer != null ? 'Edit Customer' : 'Add Customer',
                      style: AppTextStyle.headlineSmall,
                      fontWeight: FontWeight.bold,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Customer Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: siteNameCtrl,
                            decoration: const InputDecoration(
                              labelText:
                                  'Customer Site Name (e.g. Plant 2 / Site A)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.factory_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Field required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: locCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Address / Location',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin_drop_rounded),
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
                                    labelText: 'City (optional)',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.location_city_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: districtCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'District (optional)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.map_rounded),
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
                                onPressed: () => Navigator.of(sheetCtx).pop(),
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
                                    if (editCustomer?['id'] != null)
                                      'id': editCustomer!['id'],
                                    'name': nameCtrl.text.trim(),
                                    'siteName': siteNameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'location': locCtrl.text.trim(),
                                    'address': locCtrl.text.trim(),
                                    'city': cityCtrl.text.trim(),
                                    'district': districtCtrl.text.trim(),
                                  };
                                  Navigator.of(sheetCtx).pop();
                                  controller.saveCustomer(data);
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
    String vehicleType = editModeTruck?['type'] ?? '12W';

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
                  labelText: 'Truck Number Plate',
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
                  labelText: 'Truck Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Field required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: '4W', child: Text('4 Wheel (4W)')),
                  DropdownMenuItem(value: '6W', child: Text('6 Wheel (6W)')),
                  DropdownMenuItem(value: '12W', child: Text('12 Wheel (12W)')),
                ],
                onChanged: (val) {
                  if (val != null) vehicleType = val;
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
                  'type': vehicleType,
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
                                onTap: () => pick((b) => photoBytes = b),
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
                                title: const AppText(
                                    'Heavy Vehicle Applicable?',
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
                                        borderRadius: BorderRadius.circular(8)),
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
                      child: Icon(icon, color: AppColors.primary, size: 24),
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
                      color: hasImage ? AppColors.success : AppColors.textHint),
                ],
              ),
            ),
            Icon(
              hasImage ? Icons.check_circle_rounded : Icons.upload_file_rounded,
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
      // Fallback: Generate mock history logs based on current status dynamically to avoid fake future steps
      final status = (trip['status'] ?? 'ASSIGNED').toString();
      final tripDate = trip['date'] ?? 'Today';
      final pLocation = trip['pickupLocation'] ?? 'Terminal Gate';
      final pLat = trip['pickupLatitude'] ?? 18.9482;
      final pLng = trip['pickupLongitude'] ?? 72.9469;

      // 1. Initial Assignment milestone
      logs.add({
        'milestone': 0,
        'label': 'Trip Assigned by Admin',
        'timestamp': tripDate,
        'address': pLocation,
        'latitude': pLat,
        'longitude': pLng,
      });

      // 2. Acceptance milestone
      if (status != 'PENDING') {
        logs.add({
          'milestone': 1,
          'label': 'Trip Accepted by Driver',
          'timestamp': trip['confirmedAt'] ?? tripDate,
          'address': pLocation,
          'latitude': pLat,
          'longitude': pLng,
        });
      }

      // 3. En Route to Vendor milestone
      final hasStartedVendor = const {
        'EN_ROUTE_VENDOR',
        'LOADING',
        'LOAD_REQUESTED',
        'LOAD_REJECTED',
        'ACTIVE NOW',
        'DELIVERY_REQUESTED',
        'DELIVERY_REJECTED',
        'DELIVERED'
      }.contains(status);
      if (hasStartedVendor) {
        logs.add({
          'milestone': 2,
          'label': 'En Route to Vendor (On The Way)',
          'timestamp': tripDate,
          'address': pLocation,
          'latitude': pLat,
          'longitude': pLng,
        });
      }

      // 4. Loading milestone
      final hasStartedLoading = const {
        'LOADING',
        'LOAD_REQUESTED',
        'LOAD_REJECTED',
        'ACTIVE NOW',
        'DELIVERY_REQUESTED',
        'DELIVERY_REJECTED',
        'DELIVERED'
      }.contains(status);
      if (hasStartedLoading) {
        logs.add({
          'milestone': 3,
          'label': 'Reached Vendor — Loading Started',
          'timestamp': tripDate,
          'address': pLocation,
          'latitude': pLat,
          'longitude': pLng,
        });
      }

      // 5. Loaded / Awaiting approval milestone
      final hasRequestedLoad = const {
        'LOAD_REQUESTED',
        'ACTIVE NOW',
        'DELIVERY_REQUESTED',
        'DELIVERY_REJECTED',
        'DELIVERED'
      }.contains(status);
      if (hasRequestedLoad) {
        logs.add({
          'milestone': 4,
          'label': 'Cargo Loaded — Awaiting Admin Approval',
          'timestamp': tripDate,
          'address': pLocation,
          'latitude': pLat,
          'longitude': pLng,
        });
      }

      // 6. Active (On the way to destination) milestone
      final hasStartedDestination = const {
        'ACTIVE NOW',
        'DELIVERY_REQUESTED',
        'DELIVERY_REJECTED',
        'DELIVERED'
      }.contains(status);
      if (hasStartedDestination) {
        logs.add({
          'milestone': 5,
          'label': 'On The Way (Destination)',
          'timestamp': tripDate,
          'address': trip['dropLocation'] ?? 'Destination Gate',
          'latitude': trip['dropLatitude'] ?? pLat,
          'longitude': trip['dropLongitude'] ?? pLng,
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
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
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
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
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
                                        dialogCtx, isDark, logs,
                                        trip: liveTrip),
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
                              _buildMilestonesTimeline(dialogCtx, isDark, logs,
                                  trip: liveTrip),
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
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                          _buildMilestonesTimeline(context, isDark, logs,
                              trip: liveTrip),
                          const SizedBox(height: 20),
                          _buildTripExpensesPanel(
                              context, isDark, tripExpenses),
                          if (isDelivered) ...[
                            const SizedBox(height: 20),
                            _buildPODDetailsPanel(context, isDark, liveTrip),
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
    String avatarUrl = (trip['driverAvatar'] ??
            trip['driverPhoto'] ??
            trip['driverAvatarUrl'] ??
            trip['driverImage'] ??
            '')
        .toString()
        .trim();
    if (avatarUrl.isEmpty) {
      if (driverPhone.isNotEmpty) {
        avatarUrl = controller.driverAvatarFor(driverPhone);
      }
      if (avatarUrl.isEmpty && driverName.isNotEmpty) {
        avatarUrl = controller.driverAvatarFor(driverName);
      }
    }

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
                Builder(builder: (_) {
                  if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                    final corsUrl = kIsWeb
                        ? 'https://images.weserv.nl/?url=${Uri.encodeComponent(avatarUrl)}'
                        : avatarUrl;
                    return CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryLight,
                      child: ClipOval(
                        child: Image.network(
                          corsUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person_rounded,
                                color: AppColors.primary, size: 22);
                          },
                        ),
                      ),
                    );
                  }
                  return CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    radius: 22,
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.primary),
                  );
                }),
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

  static List<double>? _resolveKnownCityCoords(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    const map = <String, List<double>>{
      'vhora': [22.3482, 72.8469],
      'vihara': [22.3482, 72.8469],
      'navsari': [20.9467, 72.9520],
      'indore': [22.7196, 75.8577],
      'vadodara': [22.3072, 73.1812],
      'baroda': [22.3072, 73.1812],
      'surat': [21.1702, 72.8311],
      'ahmedabad': [23.0225, 72.5714],
      'mumbai': [19.0760, 72.8777],
      'rajkot': [22.3039, 70.8022],
      'delhi': [28.6139, 77.2090],
      'pune': [18.5204, 73.8567],
      'jaipur': [26.9124, 75.7873],
      'jnpt': [18.9482, 72.9469],
    };
    for (final entry in map.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  // Helper: High fidelity audit log vertical timeline
  Widget _buildMilestonesTimeline(
      BuildContext context, bool isDark, List<Map<String, dynamic>> logs,
      {Map<String, dynamic>? trip}) {
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
              final rawLabel = (log['label'] ?? 'Checkpoint').toString();
              final label = rawLabel.contains('Vendor ke liye nikla') ||
                      rawLabel.contains('nikla (on the way)')
                  ? 'En Route to Vendor (On The Way)'
                  : (rawLabel.contains('Vendor pahuncha') ||
                          rawLabel.contains('loading shuru')
                      ? 'Reached Vendor — Loading Started'
                      : (rawLabel.contains('Loaded — awaiting admin approval')
                          ? 'Cargo Loaded — Awaiting Admin Approval'
                          : (rawLabel.contains(
                                  'Reached Drop — awaiting delivery approval')
                              ? 'Reached Destination — Awaiting Delivery Approval'
                              : rawLabel)));
              final timestamp = log['timestamp'] ?? '';
              final rawAddress = (log['address'] ?? '').toString();
              final rawLat = (log['latitude'] as num?)?.toDouble() ?? 0.0;
              final rawLng = (log['longitude'] as num?)?.toDouble() ?? 0.0;

              final isDestMilestone = label.contains('Reached Drop') ||
                  label.contains('Delivered') ||
                  label.contains('Reached Destination') ||
                  label.contains('Destination');

              final isDummyAddress = rawAddress.isEmpty ||
                  rawAddress == 'Location Checkpoint' ||
                  rawAddress.contains('JNPT') ||
                  rawAddress == 'Terminal Gate';

              String address = rawAddress;
              if (isDummyAddress && trip != null) {
                if (isDestMilestone) {
                  address =
                      (trip['dropLocation']?.toString().isNotEmpty == true)
                          ? trip['dropLocation'].toString()
                          : ((trip['dropCity']?.toString().isNotEmpty == true)
                              ? trip['dropCity'].toString()
                              : 'Destination Terminal');
                } else {
                  address =
                      (trip['pickupLocation']?.toString().isNotEmpty == true)
                          ? trip['pickupLocation'].toString()
                          : ((trip['pickupCity']?.toString().isNotEmpty == true)
                              ? trip['pickupCity'].toString()
                              : 'Pickup Terminal');
                }
              }

              final isDummyCoords = (rawLat == 0.0 && rawLng == 0.0) ||
                  ((rawLat - 18.9482).abs() < 0.001 &&
                      (rawLng - 72.9469).abs() < 0.001);

              double lat = rawLat;
              double lng = rawLng;

              if (isDummyCoords && trip != null) {
                if (isDestMilestone) {
                  lat = (trip['dropLatitude'] as num?)?.toDouble() ??
                      (trip['currentLatitude'] as num?)?.toDouble() ??
                      0.0;
                  lng = (trip['dropLongitude'] as num?)?.toDouble() ??
                      (trip['currentLongitude'] as num?)?.toDouble() ??
                      0.0;
                } else {
                  lat = (trip['pickupLatitude'] as num?)?.toDouble() ?? 0.0;
                  lng = (trip['pickupLongitude'] as num?)?.toDouble() ?? 0.0;
                }
              }

              if ((lat == 0.0 && lng == 0.0) ||
                  ((lat - 18.9482).abs() < 0.001 &&
                      (lng - 72.9469).abs() < 0.001)) {
                final cityCoords = _resolveKnownCityCoords(address);
                if (cityCoords != null) {
                  lat = cityCoords[0];
                  lng = cityCoords[1];
                }
              }

              final hasValidCoords = (lat != 0.0 && lng != 0.0) &&
                  !((lat - 18.9482).abs() < 0.001 &&
                      (lng - 72.9469).abs() < 0.001);

              final isLast = index == logs.length - 1;
              return Stack(
                children: [
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    AppText(
                                      hasValidCoords
                                          ? 'GPS Coords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                          : 'GPS Coords: Verified at Location',
                                      style: AppTextStyle.labelMedium,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final queryParam = hasValidCoords
                                            ? '$lat,$lng'
                                            : Uri.encodeComponent(
                                                '$address, India');
                                        final mapsUrl =
                                            'https://www.google.com/maps/search/?api=1&query=$queryParam';
                                        _openInMaps(mapsUrl);
                                      },
                                      child: const Row(
                                        children: [
                                          Icon(Icons.map_rounded,
                                              size: 14,
                                              color: AppColors.primary),
                                          SizedBox(width: 4),
                                          Text('Open Maps',
                                              style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildTripExpensesPanel(BuildContext context, bool isDark,
      List<Map<String, dynamic>> expensesList) {
    return const SizedBox.shrink();
  }

  /*
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
                                                child: CachedNetworkImage(
                                                  imageUrl: _getCorsWebUrl(
                                                      receiptUrl),
                                                  height: 260,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    height: 260,
                                                    color: Colors.grey.shade100,
                                                    child: const Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                  ),
                                                  errorWidget: (context, url,
                                                          error) =>
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
                                                    style: AppTextStyle
                                                        .bodyMedium),
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
                                                  style:
                                                      AppTextStyle.bodyMedium,
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
                                    side: const BorderSide(
                                        color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () =>
                                      controller.rejectExpense(exp),
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
  */

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
                  CachedNetworkImage(
                    imageUrl: _getCorsWebUrl(podUrl),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 220,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
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
                                child: CachedNetworkImage(
                                  imageUrl: _getCorsWebUrl(podUrl),
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
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

  void _showEditAdminProfileDialog(
      BuildContext context, bool isDark, SessionService session) {
    final nameCtrl = TextEditingController(text: session.name.value);
    final avatarCtrl = TextEditingController(text: session.avatarUrl.value);
    final formKey = GlobalKey<FormState>();

    // Premium avatar options
    final List<String> presetAvatars = [
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
      'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=150',
    ];

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: StatefulBuilder(
          builder: (context, setState) {
            final currentUrl = avatarCtrl.text.isNotEmpty
                ? avatarCtrl.text
                : (session.avatarUrl.value.isNotEmpty
                    ? session.avatarUrl.value
                    : 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150');

            return Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppText('Edit Profile',
                              style: AppTextStyle.headlineSmall,
                              fontWeight: FontWeight.bold),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Get.back(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Current Avatar Preview with click-to-upload capability
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primary, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.grey.shade100,
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: corsSafeImageUrl(currentUrl),
                                    fit: BoxFit.cover,
                                    width: 96,
                                    height: 96,
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        size: 48),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickAndUploadImage(setState,
                                      avatarCtrl, session.phone.value),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const AppText('Choose a Preset Avatar:',
                          style: AppTextStyle.labelMedium,
                          fontWeight: FontWeight.bold),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: presetAvatars.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final url = presetAvatars[index];
                            final isSelected = avatarCtrl.text == url ||
                                (avatarCtrl.text.isEmpty &&
                                    session.avatarUrl.value == url);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  avatarCtrl.text = url;
                                });
                              },
                              borderRadius: BorderRadius.circular(26),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: corsSafeImageUrl(url),
                                      fit: BoxFit.cover,
                                      width: 44,
                                      height: 44,
                                      errorWidget: (_, __, ___) => const Icon(
                                          Icons.person_rounded,
                                          size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Name cannot be empty' : null,
                      ),
                      const SizedBox(height: 16),
                      // Read-only Phone Number field for identity context
                      TextFormField(
                        initialValue: session.phone.value,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (ID)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_locked_rounded),
                          helperText: 'Primary account identifier (read-only)',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const AppText('Cancel',
                                style: AppTextStyle.bodyMedium),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              Get.back();
                              await controller.updateAdminProfile(
                                session.phone.value,
                                nameCtrl.text.trim(),
                                avatarCtrl.text.trim(),
                              );
                            },
                            child: const AppText('Save Changes',
                                style: AppTextStyle.bodyMedium,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(StateSetter setState,
      TextEditingController avatarCtrl, String phone) async {
    final source = await Get.bottomSheet<ImageSource>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText('Select Image Source',
                  style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const AppText('Choose from Gallery',
                    style: AppTextStyle.bodyMedium),
                onTap: () => Get.back(result: ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const AppText('Take Photo (Camera)',
                    style: AppTextStyle.bodyMedium),
                onTap: () => Get.back(result: ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    AppPopup.showLoading(message: 'Uploading Image...');
    try {
      final picked = source == ImageSource.gallery
          ? await ImagePickerHelper.pickFromGallery()
          : await ImagePickerHelper.captureFromCamera();

      if (picked == null) {
        AppPopup.hideLoading();
        return;
      }

      final downloadUrl = await controller.uploadAvatar(picked.bytes, phone);
      AppPopup.hideLoading();

      if (downloadUrl.isNotEmpty) {
        setState(() {
          avatarCtrl.text = downloadUrl;
        });
        AppSnackBar.showSuccess(
            title: 'Image Uploaded', message: 'Photo uploaded successfully.');
      } else {
        AppSnackBar.showError(
            title: 'Upload Failed',
            message: 'Could not upload image to server.');
      }
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Widget _buildExpensesTab(BuildContext context, bool isDark) {
    return const SizedBox.shrink();
  }

  Widget _buildExpensesTabOld(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: Obx(() {
          final drivers = controller.allDrivers;
          final tripIds = controller.trips
              .map((t) => (t['id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          final filteredExpenses = controller.expenses.where((exp) {
            final driverPhone = (exp['driverPhone'] ?? '').toString();
            final tripId = (exp['tripId'] ?? '').toString();
            final status = (exp['status'] ?? 'Pending').toString();

            if (controller.selectedExpenseDriver.value.isNotEmpty &&
                driverPhone != controller.selectedExpenseDriver.value) {
              return false;
            }
            if (controller.selectedExpenseTrip.value.isNotEmpty &&
                tripId != controller.selectedExpenseTrip.value) {
              return false;
            }
            if (controller.selectedExpenseStatus.value != 'All' &&
                status.toLowerCase() !=
                    controller.selectedExpenseStatus.value.toLowerCase()) {
              return false;
            }
            return true;
          }).toList();

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width >= 1200 ? 3 : (width >= 800 ? 2 : 1);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText('Expense Overview',
                            style: AppTextStyle.headlineSmall,
                            fontWeight: FontWeight.bold),
                        const SizedBox(height: 4),
                        AppText(
                            'Monitoring real-time operational costs across the fleet.',
                            style: AppTextStyle.bodyMedium,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF6B7280)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      AppSnackBar.showSuccess(
                          title: 'Export',
                          message: 'CSV Export started successfully.');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF1E293B),
                      side: BorderSide(
                          color:
                              isDark ? Colors.white24 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const AppText('Export CSV',
                        style: AppTextStyle.labelLarge),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Filter controls card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Driver Filter Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('DRIVER',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: controller
                                        .selectedExpenseDriver.value.isEmpty
                                    ? null
                                    : controller.selectedExpenseDriver.value,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Drivers'),
                                  ),
                                  ...drivers.map((d) {
                                    final phone = (d['phone'] ?? '').toString();
                                    final name =
                                        (d['name'] ?? phone).toString();
                                    return DropdownMenuItem<String>(
                                      value: phone,
                                      child: Text(name),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  controller.selectedExpenseDriver.value =
                                      val ?? '';
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Trip Filter Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('TRIP ID',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue:
                                    controller.selectedExpenseTrip.value.isEmpty
                                        ? null
                                        : controller.selectedExpenseTrip.value,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Trips'),
                                  ),
                                  ...tripIds.map((id) {
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(id),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  controller.selectedExpenseTrip.value =
                                      val ?? '';
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Status segments filter
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('STATUS',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black26
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    'All',
                                    'Pending',
                                    'Approved',
                                    'Rejected'
                                  ].map((statusOption) {
                                    final isSelected = controller
                                            .selectedExpenseStatus.value ==
                                        statusOption;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => controller
                                            .selectedExpenseStatus
                                            .value = statusOption,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark
                                                    ? AppColors.primary
                                                    : const Color(0xFF0F172A))
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: AppText(
                                            statusOption,
                                            style: AppTextStyle.labelMedium,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          style: IconButton.styleFrom(
                            side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.all(12),
                          ),
                          onPressed: () {
                            AppSnackBar.showSuccess(
                                title: 'Filters',
                                message:
                                    'More filters features are coming soon.');
                          },
                          icon: const Icon(Icons.tune_rounded),
                        )
                      ],
                    ),
                  ],
                ),
              ),

              if (filteredExpenses.isEmpty)
                Container(
                  height: 300,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.currency_rupee_rounded,
                          size: 64, color: AppColors.textHint),
                      SizedBox(height: 12),
                      AppText('No expenses found matching the criteria.',
                          style: AppTextStyle.bodyLarge),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 380,
                  ),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final exp = filteredExpenses[index];
                    final title = (exp['title'] ?? 'Expense').toString();
                    final amount = (exp['amount'] ?? '').toString();
                    final status = (exp['status'] ?? 'Pending').toString();
                    final date = (exp['date'] ?? 'Today').toString();
                    final driverPhone = (exp['driverPhone'] ?? '').toString();
                    final driverName = controller.driverNameFor(driverPhone);
                    final driverAvatar =
                        controller.driverAvatarFor(driverPhone);
                    final tripId = (exp['tripId'] ?? '').toString();
                    final receiptUrl = (exp['receiptUrl'] ?? '').toString();
                    final locationName = (exp['locationName'] ?? '').toString();

                    Color statusColor = const Color(0xFFD97706);
                    Color statusBg = const Color(0xFFFEF3C7);
                    if (status == 'Approved') {
                      statusColor = const Color(0xFF047857);
                      statusBg = const Color(0xFFDCFCE7);
                    } else if (status == 'Rejected') {
                      statusColor = const Color(0xFFDC2626);
                      statusBg = const Color(0xFFFEE2E2);
                    }

                    IconData categoryIcon = Icons.receipt_long_rounded;
                    if (title.toLowerCase().contains('fuel') ||
                        title.toLowerCase().contains('gas')) {
                      categoryIcon = Icons.local_gas_station_rounded;
                    } else if (title.toLowerCase().contains('toll')) {
                      categoryIcon = Icons.toll_rounded;
                    } else if (title.toLowerCase().contains('food') ||
                        title.toLowerCase().contains('meal')) {
                      categoryIcon = Icons.restaurant_rounded;
                    } else if (title.toLowerCase().contains('repair')) {
                      categoryIcon = Icons.construction_rounded;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.shade200,
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: corsSafeImageUrl(driverAvatar
                                            .isNotEmpty
                                        ? driverAvatar
                                        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(driverName,
                                        style: AppTextStyle.bodyLarge,
                                        fontWeight: FontWeight.bold,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    AppText(
                                        'ID: ${driverPhone.replaceAll("+91", "")}',
                                        style: AppTextStyle.labelMedium,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF6B7280)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: AppText(status.toUpperCase(),
                                    style: AppTextStyle.labelMedium,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black26
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText('EXPENSE TYPE',
                                          style: AppTextStyle.labelMedium,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF6B7280),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(categoryIcon,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF1E293B)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: AppText(title,
                                                style: AppTextStyle.bodyMedium,
                                                fontWeight: FontWeight.bold,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black26
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText('AMOUNT',
                                          style: AppTextStyle.labelMedium,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF6B7280),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                      const SizedBox(height: 4),
                                      AppText('₹$amount',
                                          style: AppTextStyle.bodyLarge,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText('Trip ID',
                                  style: AppTextStyle.labelMedium,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF6B7280)),
                              AppText(
                                  tripId.isNotEmpty ? tripId : 'Not Associated',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText('Date/Time',
                                  style: AppTextStyle.labelMedium,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF6B7280)),
                              AppText(date,
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText('Location',
                                  style: AppTextStyle.labelMedium,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF6B7280)),
                              Expanded(
                                child: AppText(
                                    locationName.isNotEmpty
                                        ? locationName
                                        : 'N/A',
                                    style: AppTextStyle.labelMedium,
                                    fontWeight: FontWeight.bold,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Divider(height: 12),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (receiptUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: corsSafeImageUrl(receiptUrl),
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                      errorWidget: (_, __, ___) => const Icon(
                                          Icons.broken_image,
                                          size: 20),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: Colors.grey,
                                      size: 20),
                                ),
                              const Spacer(),
                              if (status == 'Pending') ...[
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                        color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () =>
                                      controller.rejectExpense(exp),
                                  child: const AppText('Reject',
                                      style: AppTextStyle.labelMedium,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () =>
                                      controller.approveExpense(exp),
                                  child: const AppText('Approve',
                                      style: AppTextStyle.labelMedium,
                                      fontWeight: FontWeight.bold),
                                ),
                              ] else ...[
                                if (receiptUrl.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => _showImagePreviewDialog(
                                        context, receiptUrl),
                                    icon: const Icon(Icons.visibility_rounded,
                                        size: 16, color: AppColors.primary),
                                    label: const Text('View Receipt',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  )
                                else if (status == 'Rejected')
                                  const Text('Duplicate claim detected',
                                      style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        }),
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
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
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: corsSafeImageUrl(imageUrl),
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image_outlined,
                      size: 80,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(
      BuildContext context, String url, String label, bool isDark) {
    final safeUrl = corsSafeImageUrl(url);
    return GestureDetector(
      onTap: () => _showFullImageDialog(url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CachedNetworkImage(
                imageUrl: safeUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AppText(label,
              style: AppTextStyle.labelMedium,
              fontSize: 8,
              color: Colors.grey,
              fontWeight: FontWeight.bold),
        ],
      ),
    );
  }

  void _showFullImageDialog(String imageUrl) {
    final safeUrl = corsSafeImageUrl(imageUrl);
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
                onPressed: () => Get.back(),
              ),
            ),
            Hero(
              tag: imageUrl,
              child: Container(
                constraints:
                    const BoxConstraints(maxHeight: 500, maxWidth: 500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: safeUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveLoadDirectly(String tripId) async {
    _showTruckOwnerPassApprovalDialog(tripId);
  }

  void _showTruckOwnerPassApprovalDialog(String tripId) {
    final formKey = GlobalKey<FormState>();
    final passIdCtrl = TextEditingController(
        text:
            'TOP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final ownerNameCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String? passPhotoUrl;
    String? adminPhotoUrl;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded,
                    color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Generate Truck Owner Pass',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Pass details fill karein. Photo upload ki jarurat nahi hai — Save & Approve karne par official Truck Owner Pass PDF automatically generate hoke driver ko mil jayegi.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passIdCtrl,
                        decoration: InputDecoration(
                          labelText: 'Truck Owner Pass ID *',
                          prefixIcon: const Icon(
                              Icons.confirmation_number_rounded,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Pass ID enter karein'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Truck Owner / Transporter Name',
                          prefixIcon:
                              const Icon(Icons.business_rounded, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarksCtrl,
                        decoration: InputDecoration(
                          labelText: 'Pass Remarks / Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              passPhotoUrl != null
                                  ? Icons.check_circle_rounded
                                  : Icons.picture_as_pdf_rounded,
                              color: passPhotoUrl != null
                                  ? Colors.green
                                  : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                passPhotoUrl != null
                                    ? 'Custom Scan Document Attached ✅'
                                    : 'Auto PDF Pass Enabled (Attach Custom Scan Optional)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final url =
                                    await ImagePickerHelper.pickImageAsBase64(
                                        context, isDark);
                                if (url != null) {
                                  setStateDialog(() {
                                    passPhotoUrl = url;
                                  });
                                }
                              },
                              child: Text(
                                  passPhotoUrl != null ? 'Change' : 'Attach'),
                            ),
                            if (passPhotoUrl != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Colors.red),
                                onPressed: () {
                                  setStateDialog(() {
                                    passPhotoUrl = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Get.back();
                    AppPopup.showLoading(
                        message: 'Generating Pass PDF & Activating Trip...');
                    try {
                      String finalPassUrl = passPhotoUrl ?? '';
                      if (finalPassUrl.isEmpty) {
                        final fb = Get.find<FirebaseService>();
                        final tripDoc = await fb.getTripData(tripId);
                        final truckNo = (tripDoc?['truckNo'] ?? '').toString();
                        final driverName =
                            (tripDoc?['driverName'] ?? '').toString();
                        final driverPhone =
                            (tripDoc?['driverPhone'] ?? '').toString();
                        final pickupLocation = (tripDoc?['pickupLocation'] ??
                                tripDoc?['vendorLocation'] ??
                                '')
                            .toString();
                        final dropCity = (tripDoc?['dropCity'] ??
                                tripDoc?['dropLocation'] ??
                                '')
                            .toString();

                        final pdfBase64 =
                            await TruckOwnerPassPdfGenerator.generatePdfBase64(
                          passId: passIdCtrl.text.trim(),
                          ownerName: ownerNameCtrl.text.trim(),
                          tripId: tripId,
                          remarks: remarksCtrl.text.trim(),
                          truckNo: truckNo,
                          driverName: driverName,
                          driverPhone: driverPhone,
                          pickupLocation: pickupLocation,
                          dropCity: dropCity,
                        );

                        finalPassUrl = await fb.uploadTruckOwnerPassPhoto(
                            tripId, pdfBase64);
                      } else {
                        finalPassUrl = await Get.find<FirebaseService>()
                            .uploadTruckOwnerPassPhoto(tripId, finalPassUrl);
                      }

                      final ownerPassData = {
                        'passId': passIdCtrl.text.trim(),
                        'ownerName': ownerNameCtrl.text.trim(),
                        'remarks': remarksCtrl.text.trim(),
                        'passPhotoUrl': finalPassUrl,
                        'passDocumentUrl': finalPassUrl,
                        'passPdfUrl': finalPassUrl,
                        'generatedAt':
                            DateTime.now().toString().substring(0, 16),
                        if (adminPhotoUrl != null && adminPhotoUrl!.isNotEmpty)
                          'adminPhotoUrl': adminPhotoUrl,
                      };
                      final err = await Get.find<FirebaseService>().approveLoad(
                        tripId,
                        truckOwnerPassId: passIdCtrl.text.trim(),
                        truckOwnerPassUrl: finalPassUrl,
                        truckOwnerPassData: ownerPassData,
                      );
                      if (err != null) {
                        Get.snackbar('Alert', err,
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.orangeAccent);
                      } else {
                        Get.snackbar('Success',
                            'Truck Owner Pass PDF generated & Trip activated! 🚛',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white);
                      }
                    } catch (e) {
                      Get.snackbar('Error', e.toString(),
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.redAccent);
                    } finally {
                      AppPopup.hideLoading();
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Save Pass & Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectLoadDialog(BuildContext context, String tripId, bool isDark) {
    String selectedReason = 'Photo unclear/blurry';
    final List<String> reasons = [
      'Photo unclear/blurry',
      'Wrong truck/quantity mismatch',
      'Bill number mismatch',
      'Sequence incorrect',
      'Other'
    ];
    String selectedPhotoFlag = 'both'; // 'loading', 'gate_pass', 'both'
    final reasonCtrl = TextEditingController();

    Get.dialog(
      StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject Load Verification?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select Rejection Reason (Mandatory):',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  initialValue: selectedReason,
                  items: reasons
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedReason = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Specify Custom Reason',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Flag Specific Photo to Re-upload:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  initialValue: selectedPhotoFlag,
                  items: const [
                    DropdownMenuItem(
                        value: 'both',
                        child: Text('Both Photos',
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: 'loading',
                        child: Text('Loading Photo Only',
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: 'gate_pass',
                        child: Text('Gate Pass Photo Only',
                            style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedPhotoFlag = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                String finalReason = selectedReason;
                if (selectedReason == 'Other') {
                  finalReason = reasonCtrl.text.trim();
                  if (finalReason.isEmpty) {
                    Get.snackbar('Alert', 'Please specify a custom reason');
                    return;
                  }
                }
                Get.back();
                AppPopup.showLoading(message: 'Rejecting Load...');
                try {
                  await Get.find<FirebaseService>().rejectLoad(
                    tripId,
                    reason: finalReason,
                    flaggedPhoto: selectedPhotoFlag,
                  );
                  AppPopup.hideLoading();
                  Get.snackbar('Rejected', 'Load request rejected.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.redAccent,
                      colorText: Colors.white);
                } catch (e) {
                  AppPopup.hideLoading();
                  Get.snackbar('Error', e.toString());
                }
              },
              child:
                  const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _approveDeliveryDirectly(String tripId) async {
    AppPopup.showLoading(message: 'Approving Completion...');
    try {
      await Get.find<FirebaseService>().approveDelivery(tripId);
      AppPopup.hideLoading();
      Get.snackbar('Success', 'Trip completed successfully! 🏁',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent);
    }
  }

  void _showRejectDeliveryDialog(
      BuildContext context, String tripId, bool isDark) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Completion?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Reason likhein delivery reject karne ka:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                Get.snackbar('Alert', 'Reason input mandatory');
                return;
              }
              Get.back();
              AppPopup.showLoading(message: 'Rejecting Delivery...');
              try {
                await Get.find<FirebaseService>()
                    .rejectDelivery(tripId, reason: reason);
                AppPopup.hideLoading();
                Get.snackbar('Rejected', 'Trip delivery has been rejected.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white);
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString());
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

String _formatCurrentDateTime() {
  final now = DateTime.now();
  final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
  final amPm = now.hour >= 12 ? 'PM' : 'AM';
  final minuteStr = now.minute.toString().padLeft(2, '0');
  final monthStr = now.month.toString().padLeft(2, '0');
  final dayStr = now.day.toString().padLeft(2, '0');
  final hourStr = hour.toString().padLeft(2, '0');
  return '${now.year}-$monthStr-$dayStr $hourStr:$minuteStr $amPm';
}
