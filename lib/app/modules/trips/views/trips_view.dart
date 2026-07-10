import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trips_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_search_bar.dart';
import '../../../../widgets/trip_status_timeline.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/session_service.dart';
import '../../../routes/app_pages.dart';

/// Reference "My Trips": All / Upcoming / Ongoing / Completed tabs with
/// vendor-material trip cards. Accept/Reject stays on PENDING cards.
class TripsView extends GetView<TripsController> {
  const TripsView({super.key});

  static const filterTabs = ['All', 'Upcoming', 'Ongoing', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        title: const AppText('My Trips',
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
                  return GestureDetector(
                    onTap: () => controller.selectTab(tab),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: AppText(
                          tab,
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
      default:
        return (AppColors.secondaryLight, AppColors.textSecondary);
    }
  }

  String _driverName() {
    try {
      final name = Get.find<SessionService>().name.value;
      return name.isEmpty ? '' : name;
    } catch (_) {
      return '';
    }
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

  Widget _buildTripCard(
      BuildContext context, TripItemModel trip, bool isDark) {
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
          // Header: id + priority + status chip
          Row(
            children: [
              Expanded(
                child: AppText(trip.id,
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w800,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
              '${trip.pickupLocation}${trip.pickupDistrict.isNotEmpty ? ', ${trip.pickupDistrict}' : ''}'),
          _kvRow('Loading Pass ID', trip.loadingPassId),

          // Trip Status Timeline — collapsed by default since multiple trips
          // can be listed here; expand to see the full stage-by-stage journey.
          Material(
            color: Colors.transparent,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.textSecondary,
                title: const AppText('Trip Status Timeline',
                    style: AppTextStyle.bodyMedium, fontWeight: FontWeight.w700),
                children: [
                  TripStatusTimeline(
                    tripId: trip.id,
                    status: trip.status,
                    driverName: _driverName(),
                    truckNo: trip.truckNo,
                    dropCity: trip.dropCity,
                    milestonesLog: trip.milestonesLog,
                    tripDate: trip.date,
                  ),
                ],
              ),
            ),
          ),

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
