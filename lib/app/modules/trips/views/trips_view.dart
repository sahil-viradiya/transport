import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trips_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../widgets/app_search_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_pages.dart';
import 'driver_loading_workflow.dart';

/// Redesigned "My Trips" screen matching the target design:
/// - Compact top header with back navigation and filter/search toggle
/// - Horizontal filter chips (All, Upcoming, Ongoing, Completed, Today) with active green pill
/// - Clean, compact white trip cards with 2-column info layout (Vendor, Material, Pickup, Pass ID)
/// - Subtle divider and "View Details →" bottom action
/// - Fully responsive, long text wrapping with no overflow
class TripsView extends StatefulWidget {
  const TripsView({super.key});

  @override
  State<TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<TripsView> {
  final RxBool _showSearch = false.obs;

  static const filterTabs = [
    'All',
    'Upcoming',
    'Ongoing',
    'Completed',
    'Today',
  ];

  TripsController get controller => Get.find<TripsController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, isDark),
            Obx(() {
              if (!_showSearch.value) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppSearchBar(
                  controller: controller.searchController,
                  hintText: 'Search Trip ID, Truck #, or City',
                ),
              );
            }),
            _buildFilterChips(isDark),
            const SizedBox(height: 8),
            _buildQueuedTripsBanner(isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.fetchTripsFromFirebase,
                color: const Color(0xFF16A34A),
                child: Obx(() {
                  final trips = controller.filteredTrips;
                  if (trips.isEmpty) {
                    return _buildEmptyState(context, isDark);
                  }
                  return ListView.builder(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
                    itemCount: trips.length,
                    itemBuilder: (context, index) =>
                        _buildTripCard(context, trips[index], isDark),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact Top Header ───────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 22,
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (Get.isRegistered<HomeController>()) {
                Get.find<HomeController>().changeTabIndex(0);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'my_trips'.tr,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          Obx(() => IconButton(
                icon: Icon(
                  _showSearch.value ? Icons.filter_alt_off_rounded : Icons.filter_list_rounded,
                  color: _showSearch.value
                      ? const Color(0xFF16A34A)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  size: 22,
                ),
                onPressed: () {
                  _showSearch.toggle();
                  if (!_showSearch.value) {
                    controller.searchController.clear();
                  }
                },
              )),
        ],
      ),
    );
  }

  // ── Filter Chips Row ────────────────────────────────────────────────────────
  Widget _buildFilterChips(bool isDark) {
    return SizedBox(
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF16A34A)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF16A34A)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  // ── Queued Trips Banner ─────────────────────────────────────────────────────
  Widget _buildQueuedTripsBanner(bool isDark) {
    return Obx(() {
      final lockedCount = controller.lockedQueuedTripsCount;
      if (lockedCount <= 0) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.blue.shade800 : const Color(0xFFBFDBFE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.queue_play_next_rounded,
              size: 18,
              color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$lockedCount Next Trip${lockedCount > 1 ? 's' : ''} Queued — Pehli trip complete hone par unlock hogi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue.shade200 : const Color(0xFF1E40AF),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Status Pill Styling Helper ──────────────────────────────────────────────
  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'PENDING':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'ASSIGNED':
        return (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
      case 'DELIVERED':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'REJECTED':
      case 'LOAD_REJECTED':
      case 'DELIVERY_REJECTED':
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      case 'ACTIVE NOW':
      case 'EN_ROUTE_VENDOR':
      case 'LOADING':
      case 'LOAD_REQUESTED':
      case 'DELIVERY_REQUESTED':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }

  bool _isDestinationVisible(String status) {
    return const {
      'ACTIVE NOW',
      'DELIVERY_REQUESTED',
      'DELIVERED',
    }.contains(status);
  }

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

  // ── Key-Value Info Row (Left: Label, Right: Value) ───────────────────────────
  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.25,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Trip Card ──────────────────────────────────────────────────────────────
  Widget _buildTripCard(BuildContext context, TripItemModel trip, bool isDark) {
    final isPending = trip.status == 'PENDING';
    final (chipBg, chipFg) = _statusColors(trip.status);

    final pickupText = [
      if (trip.pickupLocation.isNotEmpty)
        trip.pickupLocation
      else if (trip.vendorLocation.isNotEmpty)
        trip.vendorLocation,
      if (trip.pickupDistrict.isNotEmpty) trip.pickupDistrict,
    ].join(', ');

    final loadingPassText = trip.loadingPassId.isNotEmpty
        ? trip.loadingPassId
        : (trip.truckOwnerPassId.isNotEmpty
            ? trip.truckOwnerPassId
            : (trip.minPassId.isNotEmpty ? trip.minPassId : '—'));

    final materialText = trip.materialName.isNotEmpty
        ? trip.materialName
        : (trip.productName.isNotEmpty ? trip.productName : '—');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Trip ID + Sequence + Priority + Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          trip.id,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trip.tripSequence > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            'Trip #${trip.tripSequence}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trip.priority) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'PRIORITY',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DashboardView.friendlyStatus(trip.status),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: chipFg,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider below Top Row
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 1,
            thickness: 1,
          ),

          // Trip Information Section
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoRow('Vendor', trip.vendorName, isDark),
                _infoRow('Material', materialText, isDark),
                _infoRow('Pickup Location', pickupText, isDark),
                _infoRow('Loading Pass ID', loadingPassText, isDark),

                // Destination details (only when approved / visible)
                if (_isDestinationVisible(trip.status)) ...[
                  _infoRow('Drop City', trip.dropCity, isDark),
                  _infoRow('Drop Location', trip.dropLocation, isDark),
                ] else if (trip.status != 'PENDING' &&
                    trip.status != 'REJECTED' &&
                    trip.status != 'DELIVERED') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Destination admin approval ke baad dikhega',
                            style: TextStyle(
                              fontSize: 11.5,
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
              ],
            ),
          ),

          // Loading Workflow stepper for active/ongoing trips
          if (_showLoadingWorkflow(trip.status))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DriverLoadingWorkflow(trip: trip),
            ),

          // PENDING → Accept / Reject actions
          if (isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded,
                            size: 15, color: Color(0xFFB45309)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ye trip aapko assign hui hai. Accept karein tabhi start kar payenge.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => controller.confirmRejectTrip(trip.id),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => controller.acceptTrip(trip.id),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Divider before View Details
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 1,
            thickness: 1,
          ),

          // View Details Action
          InkWell(
            onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(
              Routes.TRIP_DETAILS,
              arguments: {
                'tripId': trip.id,
                'isAlreadyActive': trip.isActive,
              },
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: isDark ? Colors.white38 : AppColors.textHint,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No trips for this filter.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pull down to refresh or try another tab.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
