import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trips_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_search_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';
import 'driver_loading_workflow.dart';

/// Reference "My Trips": All / Upcoming / Ongoing / Completed tabs with
/// vendor-material trip cards. Accept/Reject stays on PENDING cards.
class TripsView extends GetView<TripsController> {
  const TripsView({super.key});

  static const filterTabs = [
    'Today',
    'All',
    'Upcoming',
    'Ongoing',
    'Completed'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        title: AppText('my_trips'.tr,
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppSearchBar(
              controller: controller.searchController,
              hintText: 'Search Trip ID, Truck #, or City',
            ),
          ),
          const SizedBox(height: 4),
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
                  final label = tab == 'Today'
                      ? 'today'.tr
                      : (tab == 'All'
                          ? 'all'.tr
                          : (tab == 'Upcoming'
                              ? 'upcoming'.tr
                              : (tab == 'Ongoing'
                                  ? 'ongoing'.tr
                                  : 'completedTrips'.tr)));
                  return GestureDetector(
                    onTap: () => controller.selectTab(tab),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: AppText(
                          label,
                          style: AppTextStyle.labelMedium,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final lockedCount = controller.lockedQueuedTripsCount;
            if (lockedCount <= 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade800 : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.queue_play_next_rounded,
                      size: 20,
                      color: isDark ? Colors.blue.shade300 : AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$lockedCount Next Trip${lockedCount > 1 ? 's' : ''} Queued — Pehli trip complete hone par unlock hogi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue.shade200 : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
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
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                color: AppColors.textHint, size: 50),
                            SizedBox(height: 12),
                            AppText('No trips for this filter.',
                                style: AppTextStyle.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  controller: controller.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: trips.length,
                  itemBuilder: (context, index) =>
                      _buildTripCard(context, trips[index], isDark),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _chipColors(String status) {
    switch (status) {
      case 'PENDING':
        return (AppColors.tertiaryLight, AppColors.tertiaryDark);
      case 'DELIVERED':
        return (AppColors.primaryLight, AppColors.primaryDark);
      case 'REJECTED':
        return (const Color(0xFFFEE2E2), AppColors.error);
      case 'ACTIVE NOW':
      case 'EN_ROUTE_VENDOR':
      case 'LOADING':
      case 'LOAD_REQUESTED':
      case 'DELIVERY_REQUESTED':
        return (const Color(0xFFE0F2FE), AppColors.info);
      case 'LOAD_REJECTED':
      case 'DELIVERY_REJECTED':
        return (const Color(0xFFFEE2E2), AppColors.error);
      default:
        return (AppColors.secondaryLight, AppColors.textSecondary);
    }
  }

  /// Destination details are visible only after admin approves load.
  bool _isDestinationVisible(String status) {
    return const {
      'ACTIVE NOW',
      'DELIVERY_REQUESTED',
      'DELIVERED',
    }.contains(status);
  }

  /// Show the loading workflow stepper for these statuses.
  bool _showLoadingWorkflow(String status) {
    return const {
      'ASSIGNED',
      'EN_ROUTE_VENDOR',
      'LOADING',
      'LOAD_REQUESTED',
      'LOAD_REJECTED',
      'ACTIVE NOW',
      'DELIVERY_REJECTED',
    }.contains(status);
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppText(label,
                style: AppTextStyle.labelMedium,
                color: AppColors.textSecondary),
          ),
          Expanded(
            flex: 3,
            child: AppText(value.isEmpty ? '—' : value,
                style: AppTextStyle.bodyMedium,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripItemModel trip, bool isDark) {
    final isPending = trip.status == 'PENDING';
    final (chipBg, chipFg) = _chipColors(trip.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: id + sequence + priority + status chip
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: AppText(trip.id,
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.w800,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (trip.tripSequence > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Trip #${trip.tripSequence}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trip.priority) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(DashboardView.friendlyStatus(trip.status),
                      style: AppTextStyle.labelMedium,
                      color: chipFg,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Reference rows: Vendor / Material / Pickup Location / Loading Pass
          _kvRow('Vendor', trip.vendorName),
          _kvRow('Material', trip.materialName),
          _kvRow('Pickup Location',
              '${trip.pickupLocation.isNotEmpty ? trip.pickupLocation : trip.vendorLocation}${trip.pickupDistrict.isNotEmpty ? ', ${trip.pickupDistrict}' : ''}'),

          // Destination details — HIDDEN until admin approves (ACTIVE NOW or later)
          if (_isDestinationVisible(trip.status)) ...[
            _kvRow('Drop City', trip.dropCity),
            _kvRow('Drop Location', trip.dropLocation),
          ] else if (trip.status != 'PENDING' &&
              trip.status != 'REJECTED' &&
              trip.status != 'DELIVERED') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Destination admin approval ke baad dikhega',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Loading Workflow stepper for active/ongoing trips
          if (_showLoadingWorkflow(trip.status))
            DriverLoadingWorkflow(trip: trip),

          // View Details
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pushNamed(
                Routes.TRIP_DETAILS,
                arguments: {
                  'tripId': trip.id,
                  'isAlreadyActive': trip.isActive,
                },
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText('View Details',
                      style: AppTextStyle.labelLarge,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),

          // PENDING → Accept / Reject (unchanged functionality)
          if (isPending) ...[
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
    );
  }
}
