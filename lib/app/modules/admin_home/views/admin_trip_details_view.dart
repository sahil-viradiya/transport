import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import '../controllers/admin_home_controller.dart';
import 'package:transport/app/core/utils/image_url.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/core/utils/image_picker_helper.dart';

import 'package:transport/app/core/utils/document_viewer_helper.dart';
import 'package:transport/app/core/utils/app_image_helper.dart';
import 'package:transport/app/core/utils/truck_owner_pass_pdf_generator.dart';

class AdminTripDetailsView extends GetView<AdminHomeController> {
  const AdminTripDetailsView({super.key});

  String _getCorsWebUrl(String url) {
    if (kIsWeb && url.startsWith('http')) {
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  String _formatTimeOnly(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      if (ts.contains(RegExp(r'(AM|PM)', caseSensitive: false))) {
        final match = RegExp(r'\d{1,2}:\d{2}\s*(?:AM|PM)', caseSensitive: false).firstMatch(ts);
        if (match != null) return match.group(0)!;
      }
      
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) {
        final hour = parsed.hour;
        final minute = parsed.minute;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute < 10 ? '0$minute' : '$minute';
        final hourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
        return '$hourStr:$minStr $period';
      }
      
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(ts);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute < 10 ? '0$minute' : '$minute';
        final hourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
        return '$hourStr:$minStr $period';
      }
    } catch (_) {}
    return ts;
  }

  String _cleanMilestoneLabel(String? raw) {
    final text = raw ?? 'Checkpoint';
    if (text.contains('Vendor ke liye nikla') || text.contains('nikla (on the way)')) {
      return 'En Route to Vendor (On The Way)';
    }
    if (text.contains('Vendor pahuncha') || text.contains('loading shuru')) {
      return 'Reached Vendor — Loading Started';
    }
    if (text.contains('Loaded — awaiting admin approval')) {
      return 'Cargo Loaded — Awaiting Admin Approval';
    }
    if (text.contains('Reached Drop — awaiting delivery approval')) {
      return 'Reached Destination — Awaiting Delivery Approval';
    }
    return text;
  }

  void _openInMaps(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripId = Get.arguments?['tripId'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Obx(() {
          final trip = controller.trips.firstWhereOrNull((t) => t['id'] == tripId);
          if (trip == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alt_route_rounded, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const AppText(
                    'Trip details not found',
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final status = (trip['status'] ?? 'ASSIGNED').toString();
          final isDelivered = status == 'DELIVERED';
          final driverPhone = (trip['driverPhone'] ?? '').toString();

          // Resolve driver name:
          // 1. Use driverName stored in the trip document (most reliable)
          // 2. Fall back to phone-normalised lookup in the users list
          // 3. Fall back to the phone itself — NEVER a hardcoded name
          final rawDriverName = (trip['driverName'] ?? '').toString().trim();
          final driverName = rawDriverName.isNotEmpty
              ? rawDriverName
              : () {
                  if (driverPhone.isEmpty) return 'Unknown Driver';
                  final cleanPhone =
                      driverPhone.replaceAll(RegExp(r'[^\d]'), '');
                  final u = controller.users.firstWhereOrNull((u) {
                    final uPhone = (u['phone'] ?? '')
                        .toString()
                        .replaceAll(RegExp(r'[^\d]'), '');
                    return uPhone.isNotEmpty &&
                        cleanPhone.isNotEmpty &&
                        (uPhone == cleanPhone ||
                            uPhone.endsWith(cleanPhone) ||
                            cleanPhone.endsWith(uPhone));
                  });
                  final name = (u?['name'] ?? u?['driverName'] ?? '')
                      .toString()
                      .trim();
                  return name.isNotEmpty ? name : driverPhone;
                }();

          // Resolve Milestones Log
          final rawLogs = trip['milestonesLog'] as List?;
          final List<Map<String, dynamic>> logs = [];
          if (rawLogs != null && rawLogs.isNotEmpty) {
            for (var item in rawLogs) {
              if (item is Map) {
                logs.add(Map<String, dynamic>.from(item));
              }
            }
          } else {
            final tripDate = trip['date'] ?? 'Today';
            final pLocation = trip['pickupLocation'] ?? 'Terminal Gate';
            final pLat = trip['pickupLatitude'] ?? 22.3039;
            final pLng = trip['pickupLongitude'] ?? 70.8022;

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
              'EN_ROUTE_VENDOR', 'LOADING', 'LOAD_REQUESTED', 'LOAD_REJECTED',
              'ACTIVE NOW', 'DELIVERY_REQUESTED', 'DELIVERY_REJECTED', 'DELIVERED'
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
              'LOADING', 'LOAD_REQUESTED', 'LOAD_REJECTED',
              'ACTIVE NOW', 'DELIVERY_REQUESTED', 'DELIVERY_REJECTED', 'DELIVERED'
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
              'LOAD_REQUESTED', 'ACTIVE NOW', 'DELIVERY_REQUESTED', 'DELIVERY_REJECTED', 'DELIVERED'
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
              'ACTIVE NOW', 'DELIVERY_REQUESTED', 'DELIVERY_REJECTED', 'DELIVERED'
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

          final tripExpenses = controller.expenses
              .where((exp) => exp['tripId'] == trip['id'])
              .toList();

          final screenWidth = MediaQuery.of(context).size.width;
          final isWebOrDesktop = screenWidth > 900;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Title Custom Header Row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 24),
                      onPressed: () => Get.back(),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Trip Details',
                            style: AppTextStyle.headlineSmall,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AppText(
                                trip['id'] ?? 'TRP-UNKNOWN',
                                style: AppTextStyle.labelLarge,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDelivered ? const Color(0xFF047857) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (status == 'DELIVERY_REQUESTED') ...[
                      ElevatedButton.icon(
                        onPressed: () => _approveDeliveryDirectly(trip['id']),
                        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: const Text('Approve Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showRejectDeliveryDialog(context, trip['id'], isDark),
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const AppText('Reject Delivery', style: AppTextStyle.labelMedium),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (status == 'LOAD_REQUESTED') ...[
                      ElevatedButton.icon(
                        onPressed: () => _approveLoadDirectly(trip['id']),
                        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: const Text('Approve Load', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showRejectLoadDialog(context, trip['id'], isDark),
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const AppText('Reject Load', style: AppTextStyle.labelMedium),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Action Buttons: Print & Cancel
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.snackbar('Print', 'Print receipt requested.', snackPosition: SnackPosition.BOTTOM);
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const AppText('Print', style: AppTextStyle.labelMedium),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('Cancel Trip?'),
                            content: Text('Are you sure you want to cancel trip ${trip['id']}? This action is irreversible.'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () => Get.back(result: true),
                                child: const Text('Cancel Trip', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          controller.deleteTrip(trip['id']);
                          Get.back();
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const AppText('Cancel Trip', style: AppTextStyle.labelMedium),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Locations Overview Card
                _buildLocationsOverviewCard(context, isDark, trip),
                const SizedBox(height: 24),

                // New: Pass & Royalty Details Card
                _buildPassRoyaltyDetailsCard(context, isDark, trip),
                const SizedBox(height: 24),

                // 2b. Verification Proofs (Loading, Truck Owner Pass, Admin Docs, POD)
                _buildVerificationProofPanel(context, isDark, trip),
                const SizedBox(height: 24),

                // 3. Driver & Vehicle Profile Cards
                _buildMetadataProfileRow(context, isDark, trip, driverName, driverPhone, isWebOrDesktop),
                const SizedBox(height: 24),

                // 4. Milestones Timeline & Expense Claims Grid
                if (isWebOrDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildMilestonesTimeline(context, isDark, logs, trip: trip),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTripExpensesPanel(context, isDark, tripExpenses, trip['id']),
                            if (isDelivered) ...[
                              const SizedBox(height: 24),
                              _buildPODDetailsPanel(context, isDark, trip),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildMilestonesTimeline(context, isDark, logs, trip: trip),
                  const SizedBox(height: 24),
                  _buildTripExpensesPanel(context, isDark, tripExpenses, trip['id']),
                  if (isDelivered) ...[
                    const SizedBox(height: 24),
                    _buildPODDetailsPanel(context, isDark, trip),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocationsOverviewCard(BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final pickupCity = (trip['pickupCity'] ?? 'Rajkot').toString();
    final pickupAddr = (trip['pickupLocation'] ?? '').toString();
    final dropCity = (trip['dropCity'] ?? '').toString();
    final dropAddr = (trip['dropLocation'] ?? '').toString();

    final hasDrop = dropCity.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pickup
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('PICKUP POINT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(pickupCity, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (pickupAddr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: AppText(pickupAddr, style: AppTextStyle.labelMedium, color: Colors.grey, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow connector
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const Icon(Icons.trending_flat_rounded, color: Colors.grey, size: 24),
                    const SizedBox(height: 4),
                    AppText('Est. Distance: N/A', style: AppTextStyle.labelMedium, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                  ],
                ),
              ),

              // Drop Point
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () => _showSetDestinationDialog(context, trip),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const AppText('DROP POINT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_location_alt_rounded, size: 12, color: hasDrop ? AppColors.primary : Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: AppText(
                                hasDrop ? dropCity : 'Destination pending',
                                style: AppTextStyle.bodyLarge,
                                fontWeight: FontWeight.bold,
                                color: hasDrop ? null : Colors.grey,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!hasDrop)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                    const SizedBox(height: 4),
                    if (hasDrop && dropAddr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: AppText(dropAddr, style: AppTextStyle.labelMedium, color: Colors.grey, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 18),
                        child: Text('-', style: TextStyle(color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
          const Divider(height: 36),
          // Stepper Tracker
          _buildMockupStepper(trip, isDark),
        ],
      ),
    );
  }

  Widget _buildMockupStepper(Map<String, dynamic> trip, bool isDark) {
    final currentMilestone = trip['currentMilestone'] as int? ?? 1;
    final status = (trip['status'] ?? '').toString();
    
    int activeStep = currentMilestone;
    if (status == 'DELIVERED') {
      activeStep = 4;
    }

    final stepLabels = ['Assigned', 'Pickup', 'Loaded', 'Delivered'];

    return Column(
      children: [
        Row(
          children: List.generate(4, (index) {
            final stepNum = index + 1;
            final isCompleted = stepNum < activeStep;
            final isActive = stepNum == activeStep;

            return Expanded(
              child: Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: (index <= activeStep - 1)
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade200,
                      ),
                    ),
                  
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFF59E0B) : (isCompleted ? const Color(0xFFFEF3C7) : Colors.grey.shade50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isCompleted || isActive) ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isActive
                        ? const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16)
                        : Text(
                            '$stepNum',
                            style: TextStyle(
                              color: (isCompleted || isActive) ? const Color(0xFFD97706) : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),

                  if (index < 3)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: (index < activeStep - 1)
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            final stepNum = index + 1;
            final isActive = stepNum == activeStep;
            return Expanded(
              child: Text(
                stepLabels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFD97706)
                      : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                  fontSize: 11,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMetadataProfileRow(BuildContext context, bool isDark, Map<String, dynamic> trip, String driverName, String driverPhone, bool isWide) {
    final truckNo = trip['truckNo'] ?? 'GJ 21 CB 3305';
    final gpsAddress = trip['currentAddress']?.isNotEmpty == true
        ? 'Sync Status: Active (${trip['currentAddress']})'
        : 'Sync Status: Awaiting GPS...';

    final adminCtrl = Get.isRegistered<AdminHomeController>() ? Get.find<AdminHomeController>() : null;
    String avatarUrl = (trip['driverAvatar'] ?? trip['driverPhoto'] ?? trip['driverAvatarUrl'] ?? trip['driverImage'] ?? '').toString().trim();
    if (avatarUrl.isEmpty && adminCtrl != null) {
      if (driverPhone.isNotEmpty) avatarUrl = adminCtrl.driverAvatarFor(driverPhone);
      if (avatarUrl.isEmpty && driverName.isNotEmpty) avatarUrl = adminCtrl.driverAvatarFor(driverName);
    }

    final driverCard = InkWell(
      onTap: () {
        if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
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
                          child: AppText(
                            '$driverName — Driver Profile Photo',
                            style: AppTextStyle.bodyMedium,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.network(
                        _getCorsWebUrl(avatarUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          Get.snackbar('Driver Profile', '$driverName (${driverPhone.isNotEmpty ? driverPhone : "No Phone"})', snackPosition: SnackPosition.BOTTOM);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Builder(builder: (_) {
              if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                final corsUrl = _getCorsWebUrl(avatarUrl);
                return CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFD1FAE5),
                  child: ClipOval(
                    child: Image.network(
                      corsUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person_rounded, color: Color(0xFF047857), size: 22);
                      },
                    ),
                  ),
                );
              }
              return const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(Icons.person_rounded, color: Color(0xFF047857), size: 22),
              );
            }),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('DRIVER PROFILE', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                  const SizedBox(height: 4),
                  AppText(driverName, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      AppText(driverPhone, style: AppTextStyle.labelMedium, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );

    final vehicleCard = InkWell(
      onTap: () {
        Get.snackbar('GPS Tracking', 'Vehicle sync status checked.', snackPosition: SnackPosition.BOTTOM);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF1E40AF), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('VEHICLE ASSIGNED', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                  const SizedBox(height: 4),
                  AppText(truckNo, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AppText(gpsAddress, style: AppTextStyle.labelMedium, color: Colors.grey, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: driverCard),
          const SizedBox(width: 24),
          Expanded(child: vehicleCard),
        ],
      );
    }

    return Column(
      children: [
        driverCard,
        const SizedBox(height: 16),
        vehicleCard,
      ],
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

  Widget _buildMilestonesTimeline(BuildContext context, bool isDark, List<Map<String, dynamic>> logs, {Map<String, dynamic>? trip}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'JOURNEY MILESTONES AUDIT',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final label = _cleanMilestoneLabel(log['label']?.toString());
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
                  address = (trip['dropLocation']?.toString().isNotEmpty == true)
                      ? trip['dropLocation'].toString()
                      : ((trip['dropCity']?.toString().isNotEmpty == true)
                          ? trip['dropCity'].toString()
                          : 'Destination Terminal');
                } else {
                  address = (trip['pickupLocation']?.toString().isNotEmpty == true)
                      ? trip['pickupLocation'].toString()
                      : ((trip['pickupCity']?.toString().isNotEmpty == true)
                          ? trip['pickupCity'].toString()
                          : 'Pickup Terminal');
                }
              }

              final isDummyCoords = (rawLat == 0.0 && rawLng == 0.0) ||
                  ((rawLat - 18.9482).abs() < 0.001 && (rawLng - 72.9469).abs() < 0.001);

              double lat = rawLat;
              double lng = rawLng;

              if (isDummyCoords && trip != null) {
                if (isDestMilestone) {
                  lat = (trip['dropLatitude'] as num?)?.toDouble() ??
                      (trip['currentLatitude'] as num?)?.toDouble() ?? 0.0;
                  lng = (trip['dropLongitude'] as num?)?.toDouble() ??
                      (trip['currentLongitude'] as num?)?.toDouble() ?? 0.0;
                } else {
                  lat = (trip['pickupLatitude'] as num?)?.toDouble() ?? 0.0;
                  lng = (trip['pickupLongitude'] as num?)?.toDouble() ?? 0.0;
                }
              }

              if ((lat == 0.0 && lng == 0.0) || ((lat - 18.9482).abs() < 0.001 && (lng - 72.9469).abs() < 0.001)) {
                final cityCoords = _resolveKnownCityCoords(address);
                if (cityCoords != null) {
                  lat = cityCoords[0];
                  lng = cityCoords[1];
                }
              }

              final hasValidCoords = (lat != 0.0 && lng != 0.0) &&
                  !((lat - 18.9482).abs() < 0.001 && (lng - 72.9469).abs() < 0.001);

              final isLast = index == logs.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dot Number
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 80,
                            color: Colors.grey.shade200,
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Log Card Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            _formatTimeOnly(timestamp),
                            style: AppTextStyle.labelMedium,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(label, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: AppText(address, style: AppTextStyle.labelMedium, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F4EA),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        hasValidCoords
                                            ? 'GPS Coords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                            : 'GPS Coords: Verified at Location',
                                        style: const TextStyle(
                                          color: Color(0xFF137333),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final queryParam = hasValidCoords
                                            ? '$lat,$lng'
                                            : Uri.encodeComponent('$address, India');
                                        final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$queryParam';
                                        _openInMaps(mapsUrl);
                                      },
                                      child: const Row(
                                        children: [
                                          Icon(Icons.map_rounded, size: 14, color: AppColors.primary),
                                          SizedBox(width: 4),
                                          Text('Open Maps', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTripExpensesPanel(BuildContext context, bool isDark, List<Map<String, dynamic>> expensesList, String tripId) {
    return const SizedBox.shrink();
  }

  Widget _buildPODDetailsPanel(BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final remarks = trip['remarks'] ?? 'No delivery comments left.';
    final podUrl = trip['podUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'PROOF OF DELIVERY (POD)',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const AppText('DRIVER REMARKS / NOTES', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
            ),
            child: AppText(remarks, style: AppTextStyle.bodyMedium),
          ),
          const SizedBox(height: 20),

          if (podUrl.isNotEmpty) ...[
            const AppText('SCANNED DOCUMENT PREVIEW', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    _getCorsWebUrl(podUrl),
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 260,
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textHint),
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
                                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                                    onPressed: () => Navigator.of(dialogCtx).pop(),
                                  ),
                                ],
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _getCorsWebUrl(podUrl),
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, st) => Container(
                                    height: 200,
                                    color: Colors.white10,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Enlarge Scan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationProofPanel(BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final status = (trip['status'] ?? '').toString();
    final tripId = (trip['id'] ?? '').toString();

    final loadingPhotoUrl = (trip['loadingPhotoUrl'] ?? '').toString();
    final gatePassPhotoUrl = (trip['gatePassPhotoUrl'] ?? '').toString();
    final podUrl = (trip['podUrl'] ?? '').toString();
    final remarks = (trip['remarks'] ?? '').toString();

    final passData = trip['truckOwnerPassData'] as Map?;
    final truckOwnerPassId = (trip['truckOwnerPassId'] ?? passData?['passId'] ?? '').toString();
    String truckOwnerPassUrl = (trip['truckOwnerPassUrl'] ?? '').toString().trim();
    if (truckOwnerPassUrl.isEmpty && passData != null) {
      truckOwnerPassUrl = (passData['passPhotoUrl'] ??
              passData['passDocumentUrl'] ??
              passData['adminPhotoUrl'] ??
              passData['truckOwnerPassUrl'] ??
              '')
          .toString()
          .trim();
    }

    String destinationDocUrl = (trip['destinationDocUrl'] ?? '').toString().trim();
    if (destinationDocUrl.isEmpty) {
      destinationDocUrl = (trip['destinationPhotoUrl'] ??
              trip['adminDocUrl'] ??
              trip['adminPhotoUrl'] ??
              '')
          .toString()
          .trim();
    }

    final hasTruckOwnerPass = (trip['hasTruckOwnerPass'] == true) ||
        truckOwnerPassId.isNotEmpty ||
        truckOwnerPassUrl.isNotEmpty ||
        passData != null;

    final hasLoadingProof = loadingPhotoUrl.isNotEmpty || gatePassPhotoUrl.isNotEmpty;
    final hasPodProof = podUrl.isNotEmpty;
    final hasAdminProof = hasTruckOwnerPass || destinationDocUrl.isNotEmpty;

    if (!hasLoadingProof && !hasPodProof && !hasAdminProof) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'VERIFICATION PROOFS',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // A. Loading Proof Section
          if (hasLoadingProof) ...[
            const AppText('LOADING STAGE PROOFS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              children: [
                if (loadingPhotoUrl.isNotEmpty) ...[
                  _buildPhotoThumbnail(context, loadingPhotoUrl, 'Loading Photo', isDark),
                  const SizedBox(width: 12),
                ],
                if (gatePassPhotoUrl.isNotEmpty) ...[
                  _buildPhotoThumbnail(context, gatePassPhotoUrl, 'Gate Pass Photo', isDark),
                ],
              ],
            ),
            if (status == 'LOAD_REJECTED') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Load Rejected: ${trip['loadRejectReason'] ?? 'None'}',
                      style: AppTextStyle.labelMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF991B1B),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'Flagged photo: ${trip['flaggedPhoto'] == 'loading' ? 'Loading Photo Only' : trip['flaggedPhoto'] == 'gate_pass' ? 'Gate Pass Photo Only' : 'Both Photos'}',
                      style: AppTextStyle.labelMedium,
                      fontSize: 11,
                      color: const Color(0xFFB91C1C),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // B. Admin & Truck Owner Pass Section
          if (hasAdminProof) ...[
            const AppText('TRUCK OWNER PASS & ADMIN DOCUMENTS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (truckOwnerPassUrl.isNotEmpty) ...[
                  _buildPhotoThumbnail(context, truckOwnerPassUrl, 'Truck Owner Pass', isDark),
                  const SizedBox(width: 12),
                ] else if (hasTruckOwnerPass) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText('Truck Owner Pass Issued ✅', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                                if (truckOwnerPassId.isNotEmpty)
                                  AppText('Pass ID: #$truckOwnerPassId', style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                                if (passData?['ownerName']?.toString().isNotEmpty == true)
                                  AppText('Owner/Transporter: ${passData!['ownerName']}', style: AppTextStyle.bodyMedium, color: Colors.grey),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (destinationDocUrl.isNotEmpty) ...[
                  _buildPhotoThumbnail(context, destinationDocUrl, 'Destination Doc/Photo', isDark),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],

          // C. POD Proof Section
          if (hasPodProof) ...[
            const AppText('PROOF OF DELIVERY (POD)', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 12),
            if (remarks.isNotEmpty) ...[
              const AppText('DRIVER REMARKS / NOTES', style: AppTextStyle.labelMedium, color: Colors.grey),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                ),
                child: AppText(remarks, style: AppTextStyle.bodyMedium),
              ),
              const SizedBox(height: 16),
            ],
            _buildPhotoThumbnail(context, podUrl, 'POD Document', isDark),
            if (status == 'DELIVERY_REJECTED') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: AppText(
                  'Delivery Rejected: ${trip['deliveryRejectReason'] ?? 'None'}',
                  style: AppTextStyle.labelMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // D. Approve / Reject Action row inside the card for awaiting approval
          if (status == 'LOAD_REQUESTED') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectLoadDialog(context, tripId, isDark),
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Reject Load', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveLoadDirectly(tripId),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Approve Load', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'DELIVERY_REQUESTED') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDeliveryDialog(context, tripId, isDark),
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Reject Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveDeliveryDirectly(tripId),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Approve Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
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

  Widget _buildPhotoThumbnail(BuildContext context, String url, String label, bool isDark) {
    final isPdf = DocumentViewerHelper.isPdf(url);

    Widget imageWidget;
    if (isPdf) {
      imageWidget = Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 36, color: Colors.redAccent),
            SizedBox(height: 4),
            Text('PDF File', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      imageWidget = AppImageHelper.buildImageWidget(
        source: url,
        fit: BoxFit.cover,
        errorWidget: Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => DocumentViewerHelper.showDocument(context, url, title: label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: imageWidget,
            ),
          ),
          const SizedBox(height: 4),
          AppText(label, style: AppTextStyle.labelMedium, color: Colors.grey, fontWeight: FontWeight.bold),
        ],
      ),
    );
  }



  Future<void> _approveLoadDirectly(String tripId) async {
    _showTruckOwnerPassApprovalDialog(tripId);
  }

  void _showTruckOwnerPassApprovalDialog(String tripId) {
    final formKey = GlobalKey<FormState>();
    final passIdCtrl = TextEditingController(text: 'TOP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final ownerNameCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String? passPhotoUrl;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
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
                          prefixIcon: const Icon(Icons.confirmation_number_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Pass ID enter karein' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: ownerNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Truck Owner / Transporter Name',
                          prefixIcon: const Icon(Icons.business_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: remarksCtrl,
                        decoration: InputDecoration(
                          labelText: 'Pass Remarks / Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              passPhotoUrl != null ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                              color: passPhotoUrl != null ? Colors.green : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                passPhotoUrl != null
                                    ? 'Custom Scan Document Attached ✅'
                                    : 'Auto PDF Pass Enabled (Attach Custom Scan Optional)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final url = await ImagePickerHelper.pickImageAsBase64(context, isDark);
                                if (url != null) {
                                  setStateDialog(() {
                                    passPhotoUrl = url;
                                  });
                                }
                              },
                              child: Text(passPhotoUrl != null ? 'Change' : 'Attach'),
                            ),
                            if (passPhotoUrl != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
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
                    AppPopup.showLoading(message: 'Generating Pass PDF & Activating Trip...');
                    try {
                      String finalPassUrl = passPhotoUrl ?? '';
                      if (finalPassUrl.isEmpty) {
                        // Automatically generate official PDF Truck Owner Pass
                        final fb = Get.find<FirebaseService>();
                        final tripDoc = await fb.getTripData(tripId);
                        final truckNo = (tripDoc?['truckNo'] ?? '').toString();
                        final driverName = (tripDoc?['driverName'] ?? '').toString();
                        final driverPhone = (tripDoc?['driverPhone'] ?? '').toString();
                        final pickupLocation = (tripDoc?['pickupLocation'] ?? tripDoc?['vendorLocation'] ?? '').toString();
                        final dropCity = (tripDoc?['dropCity'] ?? tripDoc?['dropLocation'] ?? '').toString();

                        final pdfBase64 = await TruckOwnerPassPdfGenerator.generatePdfBase64(
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

                        finalPassUrl = await fb.uploadTruckOwnerPassPhoto(tripId, pdfBase64);
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
                        'generatedAt': DateTime.now().toString().substring(0, 16),
                      };
                      final err = await Get.find<FirebaseService>().approveLoad(
                        tripId,
                        truckOwnerPassId: passIdCtrl.text.trim(),
                        truckOwnerPassUrl: finalPassUrl,
                        truckOwnerPassData: ownerPassData,
                      );
                      if (err != null) {
                        Get.snackbar('Alert', err, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orangeAccent);
                      } else {
                        Get.snackbar('Success', 'Truck Owner Pass PDF generated & Trip activated! 🚛', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
                      }
                    } catch (e) {
                      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
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
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    initialValue: selectedReason,
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
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    initialValue: selectedPhotoFlag,
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
                    await Get.find<FirebaseService>().rejectLoad(
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
      await Get.find<FirebaseService>().approveDelivery(tripId);
      AppPopup.hideLoading();
      Get.snackbar('Success', 'Trip completed successfully! 🏁', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent);
    }
  }

  void _showRejectDeliveryDialog(BuildContext context, String tripId, bool isDark) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                Get.snackbar('Alert', 'Reason input mandatory');
                return;
              }
              Get.back();
              AppPopup.showLoading(message: 'Rejecting Delivery...');
              try {
                await Get.find<FirebaseService>().rejectDelivery(tripId, reason: reason);
                AppPopup.hideLoading();
                Get.snackbar('Rejected', 'Trip delivery has been rejected.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
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

  void _showSetDestinationDialog(BuildContext context, Map<String, dynamic> trip) {
    final adminController = Get.find<AdminHomeController>();
    final formKey = GlobalKey<FormState>();
    final truckNo = (trip['truckNo'] ?? '').toString();
    final tripId = (trip['id'] ?? '').toString();

    final customerNameCtrl = TextEditingController(text: (trip['dropCity'] ?? '').toString());
    final customerSiteCtrl = TextEditingController(text: (trip['customerSite'] ?? trip['siteName'] ?? '').toString());
    final customerLocCtrl = TextEditingController(text: (trip['dropLocation'] ?? trip['location'] ?? '').toString());
    final detailsCtrl = TextEditingController();
    String? destinationDocUrl;
    TextEditingController? siteTextController;
    TextEditingController? locTextController;

    final dbCustomers = adminController.customers
        .map((c) => (c['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final customersList = dbCustomers.isNotEmpty
        ? dbCustomers
        : ["Tata Motors", "Mahindra Log", "L&T Construction", "Reliance Industries", "Adani Power"];

    final dbSites = adminController.customers
        .map((c) => (c['siteName'] ?? c['customerSite'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final sitesList = dbSites.isNotEmpty
        ? dbSites
        : ["Pune Plant", "Chennai GIDC Site", "Kolkata Port Terminal", "Delhi Central Hub", "Nagpur Depot"];

    final dbLocations = adminController.customers
        .map((c) => (c['location'] ?? c['address'] ?? c['city'] ?? '').toString().trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    final locationsList = dbLocations.isNotEmpty
        ? dbLocations
        : ["Pune, Maharashtra", "Chennai, Tamil Nadu", "Kolkata, West Bengal", "Delhi NCR", "Nagpur, Maharashtra"];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_location_alt_rounded, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Destination Setup: $truckNo',
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
                        'Step 2: Enter destination details. Upload optional photo/PDF document for driver.',
                        style: AppTextStyle.labelMedium,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),

                      // 1. Customer Name Autocomplete
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: customerNameCtrl.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final currentDbNames = adminController.customers
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
                          final foundCust = adminController.customers.firstWhereOrNull(
                              (c) => (c['name'] ?? '').toString().trim().toLowerCase() == selection.trim().toLowerCase());
                          if (foundCust != null) {
                            final site = (foundCust['siteName'] ?? foundCust['customerSite'] ?? '').toString().trim();
                            final loc = (foundCust['location'] ?? foundCust['address'] ?? foundCust['city'] ?? '').toString().trim();
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
                          final currentDbSites = adminController.customers
                              .map((c) => (c['siteName'] ?? c['customerSite'] ?? '').toString().trim())
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
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.factory_rounded, size: 18),
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
                          final currentDbLocs = adminController.customers
                              .map((c) => (c['location'] ?? c['address'] ?? c['city'] ?? '').toString().trim())
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
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.pin_drop_rounded, size: 18),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Enter delivery location' : null,
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.description_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Destination Document / Photo Attachment (Optional)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              destinationDocUrl != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                              color: destinationDocUrl != null ? Colors.green : Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                destinationDocUrl != null ? 'Destination Document Attached ✅' : 'Upload Destination Document / Photo',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final url = await ImagePickerHelper.pickImageAsBase64(context, isDark);
                                if (url != null) {
                                  setStateDialog(() {
                                    destinationDocUrl = url;
                                  });
                                }
                              },
                              child: Text(destinationDocUrl != null ? 'Change' : 'Attach'),
                            ),
                            if (destinationDocUrl != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                                onPressed: () {
                                  setStateDialog(() {
                                    destinationDocUrl = null;
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
                    if (destinationDocUrl != null && destinationDocUrl!.isNotEmpty)
                      'destinationDocUrl': destinationDocUrl,
                  };
                  Get.back();
                  AppPopup.showLoading(message: 'Saving Destination...');
                  try {
                    // Update Firestore for trip
                    await adminController.setDestination(
                      tripId,
                      data['customerName']!,
                      combinedSite,
                      destinationDocUrl: destinationDocUrl,
                    );
                    
                    // Update active truck config if truckNo is valid
                    if (truckNo.isNotEmpty && truckNo != '-') {
                      await Get.find<FirebaseService>().saveDestinationSetup(truckNo, data);
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
          );
        },
      ),
    );
  }

  Widget _buildPassRoyaltyDetailsCard(BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final material = (trip['materialName'] ?? '—').toString();
    final royalty = (trip['royaltyName'] ?? '—').toString();
    final passId = (trip['loadingPassId'] ?? '—').toString();
    final passGenTime = (trip['loadingPassGeneratedAt'] ?? '—').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              AppText(
                'PASS & ROYALTY DETAILS',
                style: AppTextStyle.labelLarge,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPassDetailRow(Icons.category_rounded, 'Material Name', material),
          const Divider(height: 24),
          _buildPassDetailRow(Icons.workspace_premium_rounded, 'Royalty Name', royalty),
          const Divider(height: 24),
          _buildPassDetailRow(Icons.confirmation_number_rounded, 'Loading Pass ID', passId),
          const Divider(height: 24),
          _buildPassDetailRow(Icons.calendar_today_rounded, 'Pass Generated At', passGenTime),
        ],
      ),
    );
  }

  Widget _buildPassDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        AppText(label, style: AppTextStyle.bodyMedium, color: Colors.grey),
        const Spacer(),
        AppText(value, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
      ],
    );
  }
}
