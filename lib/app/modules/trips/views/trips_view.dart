import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trips_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_search_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';

class TripsView extends GetView<TripsController> {
  const TripsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filterTabs = ['Today', 'Upcoming', 'Active', 'Past'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const AppText('The Highway Authority', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppSearchBar(
              controller: controller.searchController,
              hintText: 'Search Trip ID, Truck #, or City',
            ),
          ),

          // Scrollable Filter Pills
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filterTabs.length,
              itemBuilder: (context, index) {
                final tab = filterTabs[index];
                return Obx(() {
                  final isSelected = controller.activeTab.value == tab;
                  return GestureDetector(
                    onTap: () => controller.selectTab(tab),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE9F0FA)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : Colors.transparent),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: AppText(
                          tab,
                          style: AppTextStyle.labelMedium,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.secondary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
          
          const SizedBox(height: 16),

          // Dynamic Header: e.g. ASSIGNED TODAY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Obx(() => AppText(
                  'ASSIGNED ${controller.activeTab.value.toUpperCase()}',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.secondary,
                )),
          ),

          // Main List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.fetchTripsFromFirebase,
              color: AppColors.primary,
              child: Obx(() {
                final trips = controller.filteredTrips;
                
                if (trips.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, color: AppColors.textHint, size: 50),
                            SizedBox(height: 12),
                            AppText('No trips assigned for this filter.', style: AppTextStyle.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: trips.length + 1, // Include the metrics card row
                  itemBuilder: (context, index) {
                    // Put the stats cards at index 2 (simulating middle of list)
                    if (index == 2) {
                      return _buildStatsRow(isDark);
                    }

                    // Adjust index mapping for the extra stats widget
                    final tripIndex = index > 2 ? index - 1 : index;
                    if (tripIndex >= trips.length) return const SizedBox.shrink();
                    
                    final trip = trips[tripIndex];
                    return _buildTripCard(context, trip, isDark);
                  },
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripItemModel trip, bool isDark) {
    final isTripActive = trip.isActive;
    final isPending = trip.status == 'PENDING';
    final isRejected = trip.status == 'REJECTED';

    Color pillBg, pillFg, accent;
    if (isTripActive) {
      pillBg = const Color(0xFFFFF0B3);
      pillFg = const Color(0xFFBF2600);
      accent = AppColors.success;
    } else if (isPending) {
      pillBg = AppColors.tertiaryLight;
      pillFg = AppColors.tertiaryDark;
      accent = AppColors.tertiaryDark;
    } else if (isRejected) {
      pillBg = AppColors.error.withValues(alpha: 0.12);
      pillFg = AppColors.error;
      accent = AppColors.error;
    } else {
      pillBg = AppColors.primaryLight;
      pillFg = AppColors.primary;
      accent = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Details ID & Truck Info
            Row(
              children: [
                if (trip.priority) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 2),
                        AppText('PRIORITY',
                            style: AppTextStyle.labelMedium,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AppText(
                      trip.status,
                      style: AppTextStyle.labelMedium,
                      color: pillFg,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const AppText('Truck', style: AppTextStyle.labelMedium),
                const SizedBox(width: 4),
                Flexible(
                  child: AppText(trip.truckNo,
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(trip.id, style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
            
            const Divider(height: 24),

            // Pickup and drop terminals (Side-by-Side matching reference design)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pickup
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('Pickup', style: AppTextStyle.labelMedium),
                      const SizedBox(height: 2),
                      AppText(trip.pickupCity, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                      AppText(trip.pickupLocation, style: AppTextStyle.labelMedium, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                
                // Route center icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isTripActive ? Icons.local_shipping_rounded : Icons.alt_route_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                
                // Drop
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppText('Drop', style: AppTextStyle.labelMedium),
                      const SizedBox(height: 2),
                      AppText(trip.dropCity, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                      AppText(trip.dropLocation, style: AppTextStyle.labelMedium, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Date and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    AppText(trip.date, style: AppTextStyle.labelMedium),
                  ],
                ),
                if (!isPending)
                  AppButton(
                    text: isTripActive
                        ? 'Track Live'
                        : (isRejected ? 'View' : 'Details'),
                    type: isTripActive
                        ? AppButtonType.primary
                        : AppButtonType.secondary,
                    isFullWidth: false,
                    height: 36,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pushNamed(
                      Routes.TRIP_DETAILS,
                      arguments: {
                        'tripId': trip.id,
                        'isAlreadyActive': isTripActive,
                      },
                    ),
                  ),
              ],
            ),

            // PENDING → driver must Accept or Reject before it goes active.
            if (isPending) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded,
                        size: 16, color: AppColors.tertiaryDark),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Ye trip aapko assign hui hai. Accept karein tabhi start kar payenge.',
                        style: AppTextStyle.labelMedium,
                        color: AppColors.tertiaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => controller.confirmRejectTrip(trip.id),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => controller.acceptTrip(trip.id),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Side-by-side stats cards inside list view matching the design reference
  Widget _buildStatsRow(bool isDark) {
    const Color statsBlueBg = Color(0xFFE9F2FF);
    const Color statsBlueText = AppColors.primary;
    const Color statsGreyBg = Color(0xFFF0F3FA);
    const Color statsGreyText = Color(0xFF42526E);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : statsBlueBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.assignment_rounded, 
                    color: isDark ? Colors.white70 : statsBlueText, 
                    size: 24,
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    controller.pendingPickups.toString().padLeft(2, '0'),
                    style: AppTextStyle.headlineLarge,
                    color: isDark ? Colors.white : statsBlueText,
                    fontWeight: FontWeight.bold,
                  ),
                  AppText(
                    'Pending\nPickups', 
                    style: AppTextStyle.labelMedium,
                    color: isDark ? Colors.white70 : statsBlueText,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : statsGreyBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_outlined, 
                    color: isDark ? Colors.white70 : statsGreyText, 
                    size: 24,
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    controller.weeklyTrips.toString().padLeft(2, '0'),
                    style: AppTextStyle.headlineLarge,
                    color: isDark ? Colors.white : statsGreyText,
                    fontWeight: FontWeight.bold,
                  ),
                  AppText(
                    'Trips This\nWeek', 
                    style: AppTextStyle.labelMedium,
                    color: isDark ? Colors.white70 : statsGreyText,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
