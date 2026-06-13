import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:transport/widgets/app_text.dart';
import '../controllers/admin_home_controller.dart';
import '../../../core/theme/app_colors.dart';

class AdminHomeView extends GetView<AdminHomeController> {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> pages = [
      _buildAnalyticsTab(context, isDark),
      _buildTripsTab(context, isDark),
      _buildTrucksTab(context, isDark),
      _buildUsersTab(context, isDark),
    ];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      appBar: AppBar(
        title: const AppText('Highway Terminal Admin',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Logout Session',
            onPressed: controller.logout,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        return IndexedStack(
          index: controller.currentTabIndex.value,
          children: pages,
        );
      }),
      bottomNavigationBar: Obx(() => NavigationBar(
            selectedIndex: controller.currentTabIndex.value,
            onDestinationSelected: controller.changeTabIndex,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'TOTAL TRIPS',
                    '${controller.trips.length}',
                    Icons.alt_route_rounded,
                    const Color(0xFFE0F2FE),
                    const Color(0xFF0369A1),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'TOTAL TRUCKS',
                    '${controller.trucks.length}',
                    Icons.local_shipping_rounded,
                    const Color(0xFFDCFCE7),
                    const Color(0xFF15803D),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'DRIVERS / USERS',
                    '${controller.users.length}',
                    Icons.people_rounded,
                    const Color(0xFFFEF9C3),
                    const Color(0xFFA16207),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'ACTIVE DRIVERS',
                    '${controller.trips.where((t) => t['isActive'] == true).length}',
                    Icons.my_location_rounded,
                    const Color(0xFFF3E8FF),
                    const Color(0xFF7E22CE),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Tracking Panel Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppText('LIVE DRIVER TRACKING',
                    style: AppTextStyle.labelLarge,
                    fontWeight: FontWeight.bold),
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
                        Obx(() {
                          final tripId = trip['id'];
                          final tripExpenses = controller.expenses.where((exp) => exp['tripId'] == tripId).toList();
                          if (tripExpenses.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 24),
                              const AppText('EXPENSE CLAIMS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
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
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        title.contains('Fuel') ? Icons.local_gas_station_rounded : Icons.receipt_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            AppText(title, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                            if (desc.isNotEmpty)
                                              AppText(desc, style: AppTextStyle.labelMedium),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          AppText(amt, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'Approved' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: AppText(
                                              status,
                                              style: AppTextStyle.labelMedium,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'Approved' ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (receiptUrl.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.image_outlined, size: 20, color: AppColors.primary),
                                          tooltip: 'View Receipt',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                title: AppText(title, style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Image.network(
                                                        receiptUrl,
                                                        height: 260,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.broken_image_outlined, size: 80),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    AppText('Amount: $amt', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                                                    if (desc.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      AppText(desc, style: AppTextStyle.bodyMedium),
                                                    ],
                                                  ],
                                                ),
                                                actions: [
                                                  if (status == 'Pending')
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                      onPressed: () {
                                                        Navigator.of(dialogCtx).pop();
                                                        controller.approveExpense(exp);
                                                      },
                                                      child: const AppText('Approve', style: AppTextStyle.bodyMedium, color: Colors.white),
                                                    ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(dialogCtx).pop(),
                                                    child: const AppText('Close', style: AppTextStyle.bodyMedium),
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
      Color textCol, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
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
              Icon(icon, color: isDark ? AppColors.primary : textCol, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          AppText(value,
              style: AppTextStyle.headlineLarge,
              color: isDark ? Colors.white : textCol,
              fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                          AppText('Truck: ${trip['truckNo']}',
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold),
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
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: AppColors.primary, size: 20),
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
        backgroundColor: AppColors.primary,
        onPressed: () => _showTripFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 3: TRUCKS MANAGEMENT ---
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.local_shipping_rounded,
                          color: isEnRoute ? Colors.green : AppColors.primary,
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
                      onPressed: () => controller.deleteTruck(truck['truckNo']),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showTruckFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 4: ROLES & USERS MANAGEMENT ---
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
        backgroundColor: AppColors.primary,
        onPressed: () => _showUserFormDialog(context, isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- POPUP DIALOG FORM HELPERS ---

  // 1. ADD / EDIT TRIP DIALOG

  void _showTripFormDialog(BuildContext context, bool isDark,
      {Map<String, dynamic>? editModeTrip}) {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(
        text: editModeTrip?['id'] ?? '');
    final pickupCityCtrl =
        TextEditingController(text: editModeTrip?['pickupCity'] ?? '');
    final pickupLocCtrl = TextEditingController(
        text: editModeTrip?['pickupLocation'] ?? '');
    final dropCityCtrl =
        TextEditingController(text: editModeTrip?['dropCity'] ?? '');
    final dropLocCtrl = TextEditingController(
        text: editModeTrip?['dropLocation'] ?? '');
    final dateCtrl = TextEditingController(
        text: editModeTrip?['date'] ?? '');

    final availableTrucks =
        controller.trucks.map((t) => t['truckNo'] as String).toList();
    if (availableTrucks.isEmpty) availableTrucks.add('MH-12-BV-0045');
    String selectedTruck = editModeTrip?['truckNo'] ?? availableTrucks.first;

    final availableDrivers = controller.users
        .where((u) => u['role'] == 'driver')
        .map((u) => u['phone'] as String)
        .toList();
    if (availableDrivers.isEmpty) availableDrivers.add('+919876543210');
    String selectedDriver =
        editModeTrip?['driverPhone'] ?? availableDrivers.first;

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
                                  labelText: 'Drop City',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_city_rounded),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Field required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: pickupLocCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Pickup Location',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_drop_rounded),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dropLocCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Drop Location',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_drop_rounded),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Date Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_rounded),
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
                                  final tripData = {
                                    'id': idCtrl.text.trim(),
                                    'truckNo': selectedTruck,
                                    'driverPhone': selectedDriver,
                                    'pickupCity': pickupCityCtrl.text.trim(),
                                    'pickupLocation': pickupLocCtrl.text.trim(),
                                    'dropCity': dropCityCtrl.text.trim(),
                                    'dropLocation': dropLocCtrl.text.trim(),
                                    'date': dateCtrl.text.trim(),
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
                          validator: (v) => v!.isEmpty ? 'Field required' : null,
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
                          validator: (v) => !v!.startsWith('+91') || v.length < 13
                              ? 'Format must be +91XXXXXXXXXX'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Assign Role',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'driver', child: Text('Driver')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
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
                          validator: (v) => v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                              child: const AppText('Cancel', style: AppTextStyle.bodyMedium),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final userData = {
                                    'name': nameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim().replaceAll(' ', ''),
                                    'role': role,
                                    'avatarUrl': avatarCtrl.text.trim(),
                                  };

                                  Navigator.of(bottomSheetCtx).pop();
                                  controller.createUser(userData);
                                }
                              },
                              child: const AppText('Save',
                                  style: AppTextStyle.bodyMedium, color: Colors.white),
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
}
