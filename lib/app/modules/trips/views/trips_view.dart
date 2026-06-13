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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const AppText('The Highway Authority', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: AppColors.primary),
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
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : AppColors.border),
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

          // Main List View
          Expanded(
            child: Obx(() {
              final trips = controller.filteredTrips;
              
              if (trips.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, color: AppColors.textHint, size: 50),
                      const SizedBox(height: 12),
                      const AppText('No trips assigned for this filter.', style: AppTextStyle.bodyLarge),
                    ],
                  ),
                );
              }

              return ListView.builder(
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
                  return _buildTripCard(trip, isDark);
                },
              );
            }),
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

  Widget _buildTripCard(TripItemModel trip, bool isDark) {
    final isTripActive = trip.isActive;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Details ID & Truck Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTripActive
                              ? Colors.orange.withOpacity(0.1)
                              : AppColors.primaryLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AppText(
                          trip.status,
                          style: AppTextStyle.labelMedium,
                          color: isTripActive ? Colors.orange : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(trip.id, style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppText('Truck #', style: AppTextStyle.labelMedium),
                      const SizedBox(height: 4),
                      AppText(trip.truckNo, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    ],
                  ),
                ],
              ),
              
              const Divider(height: 24),

              // Pickup and drop terminals
              Row(
                children: [
                  // Terminals route icons block
                  const Icon(Icons.radio_button_checked_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText('Pickup', style: AppTextStyle.labelMedium),
                        AppText('${trip.pickupCity} (${trip.pickupLocation})', style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.textHint, size: 16),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText('Drop', style: AppTextStyle.labelMedium),
                        AppText('${trip.dropCity} (${trip.dropLocation})', style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
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
                      Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      AppText(trip.date, style: AppTextStyle.labelMedium),
                    ],
                  ),
                  AppButton(
                    text: isTripActive ? 'Track Live' : 'Details',
                    type: isTripActive ? AppButtonType.primary : AppButtonType.secondary,
                    isFullWidth: false,
                    height: 38,
                    onPressed: () => Get.toNamed(Routes.TRIP_DETAILS, arguments: {'tripId': trip.id}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Side-by-side stats cards inside list view
  Widget _buildStatsRow(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFDEEBFF).withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(height: 12),
                    AppText(
                      '${controller.pendingPickups.toString().padLeft(2, '0')} Pending',
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                    AppText('Pickups Today', style: AppTextStyle.labelMedium),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFE380).withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.history_rounded, color: AppColors.tertiaryDark, size: 28),
                    const SizedBox(height: 12),
                    AppText(
                      '${controller.weeklyTrips.toString().padLeft(2, '0')} Trips',
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                    AppText('This Active Week', style: AppTextStyle.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
