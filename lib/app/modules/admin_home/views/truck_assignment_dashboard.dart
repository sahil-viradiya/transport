import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/app/core/utils/image_url.dart';
import '../controllers/admin_home_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_trip_details_view.dart';

class DriverInfo {
  final String name;
  final String phone;
  final String avatarUrl;

  const DriverInfo({
    required this.name,
    required this.phone,
    required this.avatarUrl,
  });
}

class MockTruck {
  final String id;
  final String truckNo;
  final String name;
  String selectedType;
  String status; // 'Pending Acceptance', 'Assigned', 'Accepted'
  DriverInfo? selectedDriver;
  bool hasLoadingPass;
  Map<String, dynamic>? loadingPass;
  bool hasDestinationSetup;
  Map<String, dynamic>? destinationSetup;
  bool hasActiveTrip;
  String? activeTripStatus;
  String? activeTripPhotoUrl;
  String? activeTripGatePassUrl;
  String? activeTripPodUrl;
  String? activeTripRemarks;

  MockTruck({
    required this.id,
    required this.truckNo,
    required this.name,
    required this.selectedType,
    required this.status,
    this.selectedDriver,
    this.hasLoadingPass = false,
    this.loadingPass,
    this.hasDestinationSetup = false,
    this.destinationSetup,
    this.hasActiveTrip = false,
    this.activeTripStatus,
    this.activeTripPhotoUrl,
    this.activeTripGatePassUrl,
    this.activeTripPodUrl,
    this.activeTripRemarks,
  });
}

class TruckAssignmentDashboard extends StatefulWidget {
  final bool isDark;
  final Function(Map<String, dynamic> initialPassData)? onOpenTripForm;
  const TruckAssignmentDashboard({super.key, required this.isDark, this.onOpenTripForm});

  @override
  State<TruckAssignmentDashboard> createState() => _TruckAssignmentDashboardState();
}

class _TruckAssignmentDashboardState extends State<TruckAssignmentDashboard> {
  final _firebaseService = Get.find<FirebaseService>();
  bool isResetting = false;

  // Holds temporary driver selections on screen before the admin clicks "Assign Truck"
  final Map<String, DriverInfo> _tempSelections = {};

  DriverInfo _driverFromMap(Map<String, dynamic> u) {
    return DriverInfo(
      name: (u['name'] ?? 'Driver').toString(),
      phone: (u['phone'] ?? '').toString(),
      avatarUrl: (u['avatarUrl'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100').toString(),
    );
  }

  Widget _buildDriverAvatar(DriverInfo driver, {double radius = 14}) {
    final hasImage = driver.avatarUrl.isNotEmpty && driver.avatarUrl.startsWith('http');
    final initial = driver.name.isNotEmpty ? driver.name.substring(0, 1).toUpperCase() : 'D';
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    final color = colors[driver.name.hashCode % colors.length];

    Widget fallbackWidget() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    }

    if (hasImage) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: corsSafeImageUrl(driver.avatarUrl),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => fallbackWidget(),
          errorWidget: (context, url, error) => fallbackWidget(),
        ),
      );
    }

    return fallbackWidget();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminHomeController>();

    return Obx(() {
      final dbTrucks = controller.trucks;

      // Map DB trucks to our UI structures
      final List<MockTruck> uiTrucks = dbTrucks.map((t) {
        final truckNo = (t['truckNo'] ?? '').toString();
        final model = (t['model'] ?? 'Tata Signa').toString();
        final type = (t['type'] ?? '12W').toString();
        final assignedTo = (t['assignedTo'] ?? '').toString();
        final inspectionStatus = (t['inspectionStatus'] ?? '').toString();

        String status = 'Pending Acceptance';
        if (assignedTo.isNotEmpty) {
          if (inspectionStatus == 'pending_confirmation') {
            status = 'Pending Confirmation';
          } else if (inspectionStatus == 'ready' ||
              inspectionStatus == 'inspected_pending_review' ||
              inspectionStatus == 'approved_pending_accept') {
            status = 'Accepted';
          } else if (inspectionStatus == 'problem') {
            status = 'Problem';
          } else {
            status = 'Assigned';
          }
        }

        // Determine who driver is
        DriverInfo? selectedDriver;
        if (assignedTo.isNotEmpty) {
          final u = controller.users.firstWhereOrNull((u) => (u['phone'] ?? '') == assignedTo);
          if (u != null) {
            selectedDriver = _driverFromMap(u);
          } else {
            selectedDriver = DriverInfo(
              name: 'Assigned Driver',
              phone: assignedTo,
              avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
            );
          }
        } else if (_tempSelections.containsKey(truckNo)) {
          selectedDriver = _tempSelections[truckNo];
        }

        final hasLoadingPass = t['hasLoadingPass'] == true;
        final loadingPass = t['loadingPass'] as Map<String, dynamic>?;
        final hasDestinationSetup = t['hasDestinationSetup'] == true;
        final destinationSetup = t['destinationSetup'] as Map<String, dynamic>?;

        // Check if this truck already has an active (non-completed) trip
        String cleanTruck(String val) => val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

        final truckTrips = controller.trips.where((trip) {
          final tripTruck = (trip['truckNo'] ?? '').toString();
          return cleanTruck(tripTruck) == cleanTruck(truckNo);
        }).toList();

        // Sort by ID descending to get the latest trip first
        truckTrips.sort((a, b) => (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));

        final hasActiveTrip = truckTrips.isNotEmpty &&
            truckTrips.first['status'] != 'DELIVERED' &&
            truckTrips.first['status'] != 'REJECTED';

        return MockTruck(
          id: truckNo,
          truckNo: truckNo,
          name: model,
          selectedType: type,
          status: status,
          selectedDriver: selectedDriver,
          hasLoadingPass: hasLoadingPass,
          loadingPass: loadingPass,
          hasDestinationSetup: hasDestinationSetup,
          destinationSetup: destinationSetup,
          hasActiveTrip: hasActiveTrip,
          activeTripStatus: hasActiveTrip ? truckTrips.first['status'].toString() : null,
          activeTripPhotoUrl: hasActiveTrip ? truckTrips.first['loadingPhotoUrl']?.toString() : null,
          activeTripGatePassUrl: hasActiveTrip ? truckTrips.first['gatePassPhotoUrl']?.toString() : null,
          activeTripPodUrl: hasActiveTrip ? truckTrips.first['podUrl']?.toString() : null,
          activeTripRemarks: hasActiveTrip ? truckTrips.first['remarks']?.toString() : null,
        );
      }).toList();

      final pendingTrucks = uiTrucks.where((t) => t.status == 'Pending Acceptance').toList();
      final assignedTrucks = uiTrucks.where((t) => t.status != 'Pending Acceptance').toList();

      // Check auto reset condition reactively
      _checkAutoReset(dbTrucks);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Truck Assignment Hub',
                      style: AppTextStyle.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: 4),
                    AppText(
                      'Select a driver. Once assigned, cards move to the lower row. Drivers cannot be re-assigned.',
                      style: AppTextStyle.labelMedium,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              if (dbTrucks.any((t) => (t['assignedTo'] ?? '').toString().isNotEmpty || _tempSelections.isNotEmpty))
                TextButton.icon(
                  onPressed: _resetDemo,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // --- ROW 1: PENDING ASSIGNMENT (UPPER ROW) ---
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Unassigned Trucks (${pendingTrucks.length})',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: pendingTrucks.isEmpty
                ? _buildEmptyPlaceholder('All trucks assigned! Look below. 🎉')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: pendingTrucks.map((truck) {
                        return Padding(
                          key: ValueKey(truck.id),
                          padding: const EdgeInsets.only(right: 16, bottom: 8),
                          child: _buildInteractiveCard(truck),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // --- ROW 2: ASSIGNED & ACCEPTED (LOWER ROW) ---
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Assigned & Accepted Trucks (${assignedTrucks.length})',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 510,
            child: assignedTrucks.isEmpty
                ? _buildEmptyPlaceholder('No trucks assigned yet. Assign a truck from above.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: assignedTrucks.map((truck) {
                        return Padding(
                          key: ValueKey(truck.id),
                          padding: const EdgeInsets.only(right: 16, bottom: 8),
                          child: _buildInteractiveCard(truck),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AppText(
          message,
          style: AppTextStyle.bodyMedium,
          color: Colors.grey,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInteractiveCard(MockTruck truck) {
    final state = truck.status;
    return Container(
      width: 290,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCardBgColor(state),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getCardBorderColor(state), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(truck.truckNo, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                    AppText(truck.name, style: AppTextStyle.labelMedium, color: Colors.grey),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildStatusBadge(state),
                  if (state != 'Pending Acceptance' && state != 'Accepted') ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Reset card assignment',
                      child: GestureDetector(
                        onTap: () => _resetTruck(truck),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Truck Types Chips
          Row(
            children: [
              const AppText('Type: ', style: AppTextStyle.labelMedium, color: Colors.grey),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  truck.selectedType,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (truck.hasLoadingPass && truck.loadingPass != null && truck.loadingPass!['itemName'] != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    truck.loadingPass!['itemName'].toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (truck.hasLoadingPass && truck.loadingPass != null && truck.loadingPass!['generatedAt'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 12, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                const SizedBox(width: 4),
                AppText(
                  'Pass Gen: ${truck.loadingPass!['generatedAt']}',
                  style: AppTextStyle.labelMedium,
                  color: widget.isDark ? Colors.white38 : Colors.grey.shade600,
                  fontSize: 10,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // Driver Selection Dropdown
          InkWell(
            onTap: state == 'Pending Acceptance' ? () => _showDriverSelector(truck) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  if (truck.selectedDriver != null) ...[
                    _buildDriverAvatar(truck.selectedDriver!),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(truck.selectedDriver!.name, style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                          AppText('+91 ${truck.selectedDriver!.phone}', style: AppTextStyle.labelMedium, color: Colors.grey),
                        ],
                      ),
                    ),
                  ] else ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                      child: Icon(Icons.person_add_rounded, size: 14, color: widget.isDark ? Colors.white38 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('Select Driver', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
                          AppText('No driver assigned yet', style: AppTextStyle.labelMedium, color: Colors.grey, fontSize: 9),
                        ],
                      ),
                    ),
                  ],
                  if (state == 'Pending Acceptance')
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: widget.isDark ? Colors.white54 : Colors.grey.shade600)
                  else
                  Icon(Icons.lock_rounded, size: 10, color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (truck.hasActiveTrip && truck.activeTripStatus != null) ...[
            _buildActiveTripStatusWidget(truck),
            const SizedBox(height: 10),
          ],
          if (!(truck.hasActiveTrip && truck.hasDestinationSetup)) ...[
            // Primary Interactive Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: _buildInteractiveButton(truck),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTripStatusWidget(MockTruck truck) {
    final status = truck.activeTripStatus ?? '';
    
    // Find active trip ID
    final controller = Get.find<AdminHomeController>();
    String cleanTruck(String val) => val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final activeTrip = controller.trips.firstWhereOrNull((trip) {
      final tripTruck = (trip['truckNo'] ?? '').toString();
      final tripStatus = (trip['status'] ?? '').toString();
      return cleanTruck(tripTruck) == cleanTruck(truck.truckNo) &&
          tripStatus != 'DELIVERED' &&
          tripStatus != 'REJECTED';
    });

    if (activeTrip == null) return const SizedBox();
    final tripId = activeTrip['id'].toString();

    String label;
    IconData icon;
    Color color;

    switch (status) {
      case 'PENDING':
        label = 'Driver Confirmation Pending ⏳';
        icon = Icons.hourglass_top_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'ASSIGNED':
        label = 'Trip Accepted by Driver ✅';
        icon = Icons.check_circle_outline_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'EN_ROUTE_VENDOR':
        label = 'En Route to Vendor 🚚';
        icon = Icons.local_shipping_rounded;
        color = const Color(0xFF3B82F6);
        break;
      case 'LOADING':
        label = 'Loading at Vendor Site 📦';
        icon = Icons.hourglass_bottom_rounded;
        color = const Color(0xFF0D9488);
        break;
      case 'LOAD_REQUESTED':
        label = 'Awaiting Load Approval 📁';
        icon = Icons.rate_review_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case 'ACTIVE NOW':
        label = 'En Route to Destination 🚛';
        icon = Icons.explore_rounded;
        color = const Color(0xFF6366F1);
        break;
      case 'DELIVERY_REQUESTED':
        label = 'Awaiting Delivery Approval 🏁';
        icon = Icons.verified_rounded;
        color = const Color(0xFFF97316);
        break;
      case 'DELIVERY_REJECTED':
        label = 'Delivery Rejected - Reupload Pending ⚠️';
        icon = Icons.warning_amber_rounded;
        color = const Color(0xFFDC2626);
        break;
      case 'LOAD_REJECTED':
        label = 'Load Rejected - Reupload Pending ⚠️';
        icon = Icons.warning_amber_rounded;
        color = const Color(0xFFDC2626);
        break;
      default:
        label = 'Trip Active';
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    final hasPhoto = truck.activeTripPhotoUrl != null && truck.activeTripPhotoUrl!.isNotEmpty;
    final hasGatePassPhoto = truck.activeTripGatePassUrl != null && truck.activeTripGatePassUrl!.isNotEmpty;
    final hasPodPhoto = truck.activeTripPodUrl != null && truck.activeTripPodUrl!.isNotEmpty;
    final hasRemarks = truck.activeTripRemarks != null && truck.activeTripRemarks!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => Get.to(() => const AdminTripDetailsView(), arguments: {'tripId': tripId}),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (status == 'LOAD_REJECTED') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.isDark ? const Color(0xFF78350F) : const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejection Reason: ${activeTrip['loadRejectReason'] ?? 'None'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Flagged Photo: ${activeTrip['flaggedPhoto'] == 'loading' ? 'Loading Photo Only' : activeTrip['flaggedPhoto'] == 'gate_pass' ? 'Gate Pass Photo Only' : 'Both Photos'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark ? const Color(0xFFF59E0B) : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status == 'DELIVERY_REJECTED') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.isDark ? const Color(0xFF78350F) : const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejection Reason: ${activeTrip['deliveryRejectReason'] ?? 'None'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status == 'LOAD_REQUESTED' || (status == 'DELIVERY_REQUESTED' && hasPodPhoto)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (status == 'LOAD_REQUESTED') ...[
                _buildPhotoPreview(
                  context,
                  hasPhoto ? truck.activeTripPhotoUrl! : 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=600',
                  'Loading Proof',
                  widget.isDark,
                ),
                const SizedBox(width: 10),
                _buildPhotoPreview(
                  context,
                  hasGatePassPhoto ? truck.activeTripGatePassUrl! : 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=600',
                  'Gate Pass',
                  widget.isDark,
                ),
                const SizedBox(width: 10),
              ],
              if (status == 'DELIVERY_REQUESTED' && hasPodPhoto) ...[
                _buildPhotoPreview(
                  context,
                  truck.activeTripPodUrl!,
                  'POD Proof',
                  widget.isDark,
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ],
        if (status == 'DELIVERY_REQUESTED' && hasRemarks) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Remarks: ${truck.activeTripRemarks}',
              style: TextStyle(
                fontSize: 10,
                color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (status == 'LOAD_REQUESTED') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectLoadDialog(tripId),
                  icon: const Icon(Icons.close_rounded, size: 12),
                  label: const Text('Reject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveLoadDirectly(tripId),
                  icon: const Icon(Icons.check_rounded, size: 12),
                  label: const Text('Approve', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (status == 'DELIVERY_REQUESTED') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDeliveryDialog(tripId),
                  icon: const Icon(Icons.close_rounded, size: 12),
                  label: const Text('Reject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveDeliveryDirectly(tripId),
                  icon: const Icon(Icons.check_rounded, size: 12),
                  label: const Text('Approve', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoPreview(BuildContext context, String url, String label, bool isDark) {
    final safeUrl = corsSafeImageUrl(url);
    return GestureDetector(
      onTap: () => _showFullImageDialog(url),
      child: Tooltip(
        message: 'Click to view full $label',
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: CachedNetworkImage(
              imageUrl: safeUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                    SizedBox(height: 2),
                    Text(
                      'Failed',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Get.back(),
              ),
            ),
            Hero(
              tag: imageUrl,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: safeUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
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
    AppPopup.showLoading(message: 'Approving Load...');
    try {
      final err = await _firebaseService.approveLoad(tripId);
      AppPopup.hideLoading();
      if (err != null) {
        Get.snackbar('Alert', err, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orangeAccent);
      } else {
        Get.snackbar('Success', 'Load approved & Trip activated! 🚛', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
    }
  }

  void _showRejectLoadDialog(String tripId) {
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
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Reject Load Verification?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Rejection Reason (Mandatory):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    dropdownColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: selectedReason,
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedReason = val;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Specify Custom Reason',
                        labelStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Flag Specific Photo to Re-upload:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    dropdownColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: selectedPhotoFlag,
                    items: const [
                      DropdownMenuItem(value: 'both', child: Text('Both Photos', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'loading', child: Text('Loading Photo Only', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'gate_pass', child: Text('Gate Pass Photo Only', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedPhotoFlag = val;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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
                    await _firebaseService.rejectLoad(
                      tripId,
                      reason: finalReason,
                      flaggedPhoto: selectedPhotoFlag,
                    );
                    AppPopup.hideLoading();
                    Get.snackbar('Rejected', 'Load request rejected.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                  } catch (e) {
                    AppPopup.hideLoading();
                    Get.snackbar('Error', e.toString());
                  }
                },
                child: const Text('Reject', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _approveDeliveryDirectly(String tripId) async {
    AppPopup.showLoading(message: 'Approving Completion...');
    try {
      await _firebaseService.approveDelivery(tripId);
      AppPopup.hideLoading();
      Get.snackbar('Success', 'Trip completed successfully! 🏁', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
    }
  }

  void _showRejectDeliveryDialog(String tripId) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Completion?', style: TextStyle(fontWeight: FontWeight.bold)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                Get.snackbar('Alert', 'Please enter a reason');
                return;
              }
              Get.back();
              AppPopup.showLoading(message: 'Rejecting Delivery...');
              try {
                await _firebaseService.rejectDelivery(tripId, reason: reason);
                AppPopup.hideLoading();
                Get.snackbar('Rejected', 'Delivery request rejected.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
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

  Widget _buildStatusBadge(String state) {
    Color bg;
    Color text;
    String label = state;

    if (state == 'Pending Acceptance') {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFEA580C);
      label = 'Pending';
    } else if (state == 'Pending Confirmation') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
      label = 'Pending Confirmation';
    } else if (state == 'Assigned') {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF2563EB);
      label = 'Assigned';
    } else if (state == 'Problem') {
      bg = const Color(0xFFFFECE6);
      text = const Color(0xFFBF2600);
      label = 'Problem';
    } else {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF16A34A);
      label = 'Accepted';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildInteractiveButton(MockTruck truck) {
    final state = truck.status;
    final hasDriver = truck.selectedDriver != null;

    if (state == 'Pending Confirmation') {
      return Container(
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white10 : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade400.withOpacity(0.5)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Waiting for response',
                style: TextStyle(
                  color: widget.isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (state == 'Pending Acceptance') {
      return ElevatedButton(
        onPressed: hasDriver ? () => _assignTruck(truck) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasDriver ? const Color(0xFFF97316) : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
          foregroundColor: hasDriver ? Colors.white : (widget.isDark ? Colors.white30 : Colors.grey.shade500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text('Assign Truck', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (state == 'Assigned') {
      return Container(
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white12 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Awaiting Driver Inspection',
                style: TextStyle(
                  color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (state == 'Problem') {
      return ElevatedButton.icon(
        onPressed: () => _showProblemReportDialog(context, truck),
        icon: const Icon(Icons.report_problem_rounded, size: 14),
        label: const Text('View Report & Resolve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else {
      if (!truck.hasLoadingPass) {
        return ElevatedButton.icon(
          onPressed: () => _showLoadingPassDialog(context, truck),
          icon: const Icon(Icons.note_add_rounded, size: 14),
          label: const Text('Generate Loading Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        );
      } else if (!truck.hasDestinationSetup) {
        return ElevatedButton.icon(
          onPressed: () => _showDestinationSetupDialog(context, truck),
          icon: const Icon(Icons.add_location_alt_rounded, size: 14),
          label: const Text('Setup Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        );
      } else {
        // If trip already created, show "Trip Active" indicator instead of Create Trip
        if (truck.hasActiveTrip) {
          return Container(
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Trip Active',
                  style: TextStyle(
                    color: widget.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (truck.selectedDriver != null) {
                    final pass = truck.loadingPass ?? {};
                    final dest = truck.destinationSetup ?? {};
                    _autoCreateTrip({
                      'driverPhone': truck.selectedDriver!.phone,
                      'truckNo': truck.truckNo,
                      'vendorName': pass['vendorName'],
                      'vendorLocation': pass['vendorSite'],
                      'itemName': pass['itemName'],
                      'royaltyName': pass['royaltyName'],
                      'loadingPassId': pass['loadingPassId'] ?? '',
                      'loadingPassGeneratedAt': pass['generatedAt'] ?? '',
                      'dropCity': dest['customerName'],
                      'dropLocation': dest['customerSite'],
                      'remarks': dest['additionalDetails'],
                    });
                  }
                },
                icon: const Icon(Icons.alt_route_rounded, size: 14),
                label: const Text('Create Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Edit Loading Pass',
              child: InkWell(
                onTap: () => _showLoadingPassDialog(context, truck),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.note_alt_rounded,
                    size: 13,
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Edit Destination',
              child: InkWell(
                onTap: () => _showDestinationSetupDialog(context, truck),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.edit_location_alt_rounded,
                    size: 13,
                    color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }
  }

  Color _getCardBgColor(String state) {
    if (state == 'Accepted') {
      return widget.isDark ? const Color(0xFF064E3B).withOpacity(0.15) : const Color(0xFFF0FDF4);
    }
    if (state == 'Problem') {
      return widget.isDark ? const Color(0xFF7F1D1D).withOpacity(0.15) : const Color(0xFFFEF2F2);
    }
    if (state == 'Pending Confirmation') {
      return widget.isDark ? const Color(0xFF78350F).withOpacity(0.15) : const Color(0xFFFFFBEB);
    }
    return widget.isDark ? const Color(0xFF1E293B) : Colors.white;
  }

  Color _getCardBorderColor(String state) {
    if (state == 'Accepted') {
      return const Color(0xFF86EFAC).withOpacity(0.4);
    } else if (state == 'Assigned') {
      return const Color(0xFF93C5FD).withOpacity(0.4);
    } else if (state == 'Problem') {
      return const Color(0xFFFCA5A5).withOpacity(0.6);
    } else if (state == 'Pending Confirmation') {
      return const Color(0xFFFDE047).withOpacity(0.5);
    }
    return widget.isDark ? Colors.white10 : const Color(0xFFE5EAE7);
  }

  // Assign button click handler (Writes to Firestore!)
  Future<void> _assignTruck(MockTruck truck) async {
    if (truck.selectedDriver == null) return;
    try {
      await _firebaseService.assignTruckToDriver(truck.truckNo, truck.selectedDriver!.phone, model: truck.name);
      
      // Clean temp selections
      setState(() {
        _tempSelections.remove(truck.truckNo);
      });

      Get.snackbar(
        'Truck Assigned 🚛',
        'Truck ${truck.truckNo} assigned to ${truck.selectedDriver!.name} successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF3B82F6),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not assign truck: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  // Automatically reset all cards to top row if everything is assigned
  void _checkAutoReset(List<Map<String, dynamic>> dbTrucks) {
    if (dbTrucks.isEmpty) return;
    final unassigned = dbTrucks.where((t) => (t['assignedTo'] ?? '').toString().isEmpty).toList();
    if (unassigned.isEmpty && !isResetting) {
      isResetting = true;
      Future.delayed(const Duration(milliseconds: 1800), () async {
        try {
          // Perform reset in Firestore
          final futures = dbTrucks.map((t) => _firebaseService.unassignTruck((t['truckNo'] ?? '').toString()));
          await Future.wait(futures);

          if (mounted) {
            setState(() {
              _tempSelections.clear();
              isResetting = false;
            });

            Get.dialog(
              AlertDialog(
                backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.celebration_rounded, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Mission Completed!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text('All trucks have been assigned to their respective drivers! Board is resetting to unassigned row.'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
            );
          }
        } catch (_) {
          isResetting = false;
        }
      });
    }
  }

  void _showProblemReportDialog(BuildContext context, MockTruck truck) {
    final controller = Get.find<AdminHomeController>();
    final rawTruck = controller.trucks.firstWhereOrNull((t) => t['truckNo'] == truck.truckNo);
    if (rawTruck == null) return;

    final results = rawTruck['inspectionResults'] as Map<dynamic, dynamic>? ?? {};
    final remarks = rawTruck['inspectionRemarks']?.toString() ?? 'No remarks';
    final images = rawTruck['inspectionImages'] as List<dynamic>? ?? [];
    final driverName = truck.selectedDriver?.name ?? 'Driver';

    Get.dialog(
      AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Problem Report: ${truck.truckNo}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('Reported By: $driverName', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                const Divider(height: 16),
                const AppText('Failed Items:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.redAccent),
                const SizedBox(height: 6),
                if (results.isEmpty)
                  const AppText('No items recorded in results', style: AppTextStyle.bodyMedium, color: Colors.grey)
                else
                  ...results.entries.where((e) => e.value == false).map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
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
                  const AppText('Photos:', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
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
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
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
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Get.back();
              AppPopup.showLoading(message: 'Rejecting...');
              try {
                await _firebaseService.rejectTruckInspection(truck.truckNo);
                AppPopup.hideLoading();
                Get.snackbar('Inspection Rejected ❌', 'Driver has been requested to re-inspect.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
              }
            },
            child: const Text('Reject & Re-inspect', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Get.back();
              AppPopup.showLoading(message: 'Resolving...');
              try {
                await _firebaseService.clearTruckIssue(truck.truckNo);
                AppPopup.hideLoading();
                Get.snackbar('Issue Resolved ✅', 'Truck is now active/ready.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.success, colorText: Colors.white);
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
              }
            },
            child: const Text('Resolve & Mark Active', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLoadingPassDialog(BuildContext context, MockTruck truck) {
    final formKey = GlobalKey<FormState>();
    final pass = truck.loadingPass ?? {};

    final vendorNameCtrl = TextEditingController(text: pass['vendorName'] ?? '');
    final vendorSiteCtrl = TextEditingController(text: pass['vendorSite'] ?? '');
    final itemNameCtrl = TextEditingController(text: pass['itemName'] ?? '');
    final royaltyNameCtrl = TextEditingController(text: pass['royaltyName'] ?? '');

    final adminController = Get.find<AdminHomeController>();
    final vendors = adminController.vendors;

    final vendorsList = vendors
        .map((v) => (v['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    final sitesList = vendors
        .map((v) => (v['siteName'] ?? '').toString())
        .where((site) => site.isNotEmpty)
        .toSet()
        .toList();
    final itemsList = vendors
        .map((v) => (v['itemName'] ?? '').toString())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    if (vendorsList.isEmpty) {
      vendorsList.addAll(["Adani Coal", "Ultratech Cement", "Jindal Steel", "Ambuja Cement", "Reliance Ind"]);
    }
    if (sitesList.isEmpty) {
      sitesList.addAll(["Mundra Port", "Nagpur GIDC", "Mumbai Warehouse", "Sachin GIDC", "Indore Plant"]);
    }
    if (itemsList.isEmpty) {
      itemsList.addAll(["Coal", "Cement", "Iron Ore", "Steel Coils", "Bauxite", "Gypsum", "Aggregate", "Sand"]);
    }

    TextEditingController? siteFieldController;
    TextEditingController? itemFieldController;

    Get.dialog(
      AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_add_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Generate Loading Pass: ${truck.truckNo}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    'Details enter/search karein. Save karne par driver ko notification chali jayegi.',
                    style: AppTextStyle.labelMedium,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),

                  // Vendor Name Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: vendorNameCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return vendorsList;
                      }
                      return vendorsList.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      textEditingController.addListener(() {
                        vendorNameCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Vendor Name',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.business_rounded, size: 18),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter vendor name' : null,
                      );
                    },
                    onSelected: (String selection) {
                      vendorNameCtrl.text = selection;
                      final matched = vendors.firstWhereOrNull(
                          (v) => (v['name'] ?? '').toString() == selection);
                      if (matched != null) {
                        final site = (matched['siteName'] ?? '').toString();
                        final item = (matched['itemName'] ?? '').toString();
                        vendorSiteCtrl.text = site;
                        itemNameCtrl.text = item;
                        if (siteFieldController != null) {
                          siteFieldController!.text = site;
                        }
                        if (itemFieldController != null) {
                          itemFieldController!.text = item;
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Vendor Site Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: vendorSiteCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return sitesList;
                      }
                      return sitesList.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      siteFieldController = textEditingController;
                      textEditingController.addListener(() {
                        vendorSiteCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Vendor Site',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter vendor site' : null,
                      );
                    },
                    onSelected: (String selection) {
                      vendorSiteCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Item Name Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: itemNameCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return itemsList;
                      }
                      return itemsList.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      itemFieldController = textEditingController;
                      textEditingController.addListener(() {
                        itemNameCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.category_rounded, size: 18),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter item name' : null,
                      );
                    },
                    onSelected: (String selection) {
                      itemNameCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Royalty / Owner Name Text Field
                  TextFormField(
                    controller: royaltyNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Royalty / Owner Name',
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter royalty / owner name' : null,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final now = DateTime.now();
              final formatted = _formatDateTime(now);

              final passId = (10000000 + Random().nextInt(90000000)).toString();
              final data = {
                'vendorName': vendorNameCtrl.text.trim(),
                'vendorSite': vendorSiteCtrl.text.trim(),
                'itemName': itemNameCtrl.text.trim(),
                'royaltyName': royaltyNameCtrl.text.trim(),
                'generatedAt': formatted,
                'loadingPassId': passId,
              };
              Get.back();
              AppPopup.showLoading(message: 'Saving & Assigning Trip...');
              try {
                await _firebaseService.saveLoadingPass(truck.truckNo, data);
                
                // Automatically create and assign the trip
                if (truck.selectedDriver != null) {
                  await _autoCreateTrip({
                    'driverPhone': truck.selectedDriver!.phone,
                    'truckNo': truck.truckNo,
                    'vendorName': data['vendorName'],
                    'vendorLocation': data['vendorSite'],
                    'itemName': data['itemName'],
                    'royaltyName': data['royaltyName'],
                    'loadingPassId': data['loadingPassId'],
                    'loadingPassGeneratedAt': data['generatedAt'],
                    'dropCity': '',
                    'dropLocation': '',
                    'remarks': '',
                  });
                }
                
                AppPopup.hideLoading();
                Get.snackbar('Success', 'Loading Pass saved & Trip assigned successfully!', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.grey.shade800, colorText: Colors.white);
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
              }
            },
            child: const Text('Generate Loading Pass'),
          ),
        ],
      ),
    );
  }

  void _showDestinationSetupDialog(BuildContext context, MockTruck truck) {
    final formKey = GlobalKey<FormState>();
    final dest = truck.destinationSetup ?? {};

    final customerNameCtrl = TextEditingController(text: dest['customerName'] ?? '');
    final customerSiteCtrl = TextEditingController(text: dest['customerSite'] ?? '');
    final detailsCtrl = TextEditingController(text: dest['additionalDetails'] ?? '');

    final customersList = ["Tata Motors", "Mahindra Log", "L&T Construction", "Reliance Industries", "Adani Power"];
    final sitesList = ["Pune Hub", "Chennai GIDC", "Kolkata Port", "Delhi Depot", "Nagpur GIDC"];

    Get.dialog(
      AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_location_alt_rounded, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Destination Setup: ${truck.truckNo}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    'Step 2: Enter destination. "Save & Next" will immediately launch the Create Trip wizard.',
                    style: AppTextStyle.labelMedium,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),

                  // Customer Name Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: customerNameCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return customersList;
                      }
                      return customersList.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      textEditingController.addListener(() {
                        customerNameCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.business_rounded, size: 18),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter customer name' : null,
                      );
                    },
                    onSelected: (String selection) {
                      customerNameCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Customer Site Autocomplete
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: customerSiteCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return sitesList;
                      }
                      return sitesList.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      textEditingController.addListener(() {
                        customerSiteCtrl.text = textEditingController.text;
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Customer Site',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter customer site' : null,
                      );
                    },
                    onSelected: (String selection) {
                      customerSiteCtrl.text = selection;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Additional destination details
                  TextFormField(
                    controller: detailsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Additional Destination Details',
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.description_rounded, size: 18),
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
              final data = {
                'customerName': customerNameCtrl.text.trim(),
                'customerSite': customerSiteCtrl.text.trim(),
                'additionalDetails': detailsCtrl.text.trim(),
              };
              Get.back();
              AppPopup.showLoading(message: 'Saving Destination...');
              try {
                await _firebaseService.saveDestinationSetup(truck.truckNo, data);
                
                // Find active trip for this truck in controller.trips and update it in Firestore!
                final controller = Get.find<AdminHomeController>();
                String cleanTruck(String val) => val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
                final activeTrip = controller.trips.firstWhereOrNull((trip) {
                  final tripTruck = (trip['truckNo'] ?? '').toString();
                  final tripStatus = (trip['status'] ?? '').toString();
                  return cleanTruck(tripTruck) == cleanTruck(truck.truckNo) &&
                      tripStatus != 'DELIVERED' &&
                      tripStatus != 'REJECTED';
                });
                
                if (activeTrip != null) {
                  final tripId = activeTrip['id'].toString();
                  await _firebaseService.setTripDestination(
                    tripId,
                    dropCity: data['customerName'] ?? '',
                    dropLocation: data['customerSite'] ?? '',
                  );
                }
                
                AppPopup.hideLoading();
                Get.snackbar('Success', 'Destination setup saved successfully!', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.grey.shade800, colorText: Colors.white);
              } catch (e) {
                AppPopup.hideLoading();
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoCreateTrip(Map<String, dynamic> data) async {
    final controller = Get.find<AdminHomeController>();
    AppPopup.showLoading(message: 'Assigning Trip...');
    try {
      final tripId = await _firebaseService.generateTripId();
      final tripData = {
        'id': tripId,
        'truckNo': data['truckNo'],
        'driverPhone': data['driverPhone'],
        'vendorName': data['vendorName'],
        'vendorLocation': data['vendorLocation'],
        'pickupLocation': data['vendorLocation'],
        'materialName': data['itemName'],
        'royaltyName': data['royaltyName'],
        'dropCity': data['dropCity'],
        'dropLocation': data['dropLocation'],
        'remarks': data['remarks'] ?? '',
        'date': DateTime.now().toString().split(' ')[0], // yyyy-MM-dd
        'tabType': 'Today',
        'priority': false,
        'pickupLatitude': 18.9482,
        'pickupLongitude': 72.9469,
        'dropLatitude': 21.0792,
        'dropLongitude': 79.0274,
        'status': 'ASSIGNED',
        'isActive': false,
        'currentMilestone': 0,
        'remainingDistance': '',
        'estimatedTime': '',
        'currentAddress': '',
        'loadingPassId': data['loadingPassId'] ?? '',
        'loadingPassGeneratedAt': data['loadingPassGeneratedAt'] ?? '',
      };
      await _firebaseService.assignTripToDriver(tripId, tripData);
      AppPopup.hideLoading();
      Get.snackbar(
        'Trip Assigned ✅',
        'Trip $tripId sent to the driver for confirmation.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
      await controller.loadData();
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  void _showDriverSelector(MockTruck truck) {
    final controller = Get.find<AdminHomeController>();

    // 1. Get driver phones assigned to other trucks
    final assignedPhones = controller.trucks
        .where((t) => (t['assignedTo'] ?? '').toString().isNotEmpty && t['truckNo'] != truck.truckNo)
        .map((t) => t['assignedTo'].toString())
        .toSet();

    // Also exclude drivers selected temporarily on other unassigned trucks
    _tempSelections.forEach((key, driver) {
      if (key != truck.truckNo) {
        assignedPhones.add(driver.phone);
      }
    });

    // 2. Filter driver list to exclude already assigned drivers (only driver role)
    final availableDrivers = controller.users
        .where((u) => (u['role'] ?? 'driver') == 'driver' && !assignedPhones.contains(u['phone']))
        .map(_driverFromMap)
        .toList();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Select Driver', style: AppTextStyle.titleLarge, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            const AppText(
              'Only showing available drivers. Already assigned drivers are hidden.',
              style: AppTextStyle.labelMedium,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Unassign Option
                  if (truck.selectedDriver != null) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 16),
                      ),
                      title: const AppText('Remove / Unassign Driver', style: AppTextStyle.bodyMedium, color: Colors.red, fontWeight: FontWeight.bold),
                      subtitle: const AppText('Clear this driver selection', style: AppTextStyle.labelMedium, color: Colors.grey, fontSize: 10),
                      onTap: () {
                        _resetTruck(truck);
                        Get.back();
                      },
                    ),
                    const Divider(height: 20),
                  ],
                  if (availableDrivers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: AppText('No available drivers left!', style: AppTextStyle.bodyMedium, color: Colors.grey),
                      ),
                    )
                  else
                    ...availableDrivers.map((driver) {
                      final isCurrent = truck.selectedDriver?.phone == driver.phone;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _buildDriverAvatar(driver),
                        title: AppText(driver.name, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                        subtitle: AppText('+91 ${driver.phone}', style: AppTextStyle.labelMedium, color: Colors.grey),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _tempSelections[truck.truckNo] = driver;
                          });
                          Get.back();
                        },
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Clear driver in-place
  Future<void> _resetTruck(MockTruck truck) async {
    try {
      await _firebaseService.unassignTruck(truck.truckNo);
      setState(() {
        _tempSelections.remove(truck.truckNo);
      });
    } catch (_) {}
  }

  // Reset the entire demo board in Firestore
  Future<void> _resetDemo() async {
    try {
      final controller = Get.find<AdminHomeController>();
      final futures = controller.trucks.map((t) => _firebaseService.unassignTruck((t['truckNo'] ?? '').toString()));
      await Future.wait(futures);

      setState(() {
        _tempSelections.clear();
      });

      Get.snackbar(
        'Demo Reset 🔄',
        'All truck assignments reset to initial states.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.grey.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } catch (_) {}
  }
}

String _formatDateTime(DateTime dt) {
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  final minuteStr = dt.minute.toString().padLeft(2, '0');
  final monthStr = dt.month.toString().padLeft(2, '0');
  final dayStr = dt.day.toString().padLeft(2, '0');
  final hourStr = hour.toString().padLeft(2, '0');
  return '${dt.year}-$monthStr-$dayStr $hourStr:$minuteStr $amPm';
}
