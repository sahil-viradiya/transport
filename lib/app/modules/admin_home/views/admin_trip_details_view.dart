import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transport/widgets/app_button.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/app/core/utils/time_utils.dart';
import '../controllers/admin_home_controller.dart';

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
          final driverPhone = trip['driverPhone'] ?? 'N/A';
          final driverName = controller.users.firstWhereOrNull(
                (u) => u['phone'] == driverPhone,
              )?['name'] ??
              'DEEP';

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
            final currentMilestone = trip['currentMilestone'] as int? ?? 1;
            final tripDate = trip['date'] ?? '11:16 AM';

            logs.add({
              'milestone': 1,
              'label': 'Vendor ke liye nikla (on the way)',
              'timestamp': tripDate,
              'address': trip['pickupLocation'] ?? 'rajkot, 180 ft ring road sagun hights',
              'latitude': trip['pickupLatitude'] ?? 22.3039,
              'longitude': trip['pickupLongitude'] ?? 70.8022,
            });

            if (currentMilestone >= 2) {
              logs.add({
                'milestone': 2,
                'label': 'Reached Pickup Point',
                'timestamp': '12:05 PM',
                'address': trip['pickupLocation'] ?? 'rajkot, 180 ft ring road sagun hights',
                'latitude': trip['pickupLatitude'] ?? 22.3039,
                'longitude': trip['pickupLongitude'] ?? 70.8022,
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
                _buildLocationsOverviewCard(isDark, trip),
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
                        child: _buildMilestonesTimeline(context, isDark, logs),
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
                  _buildMilestonesTimeline(context, isDark, logs),
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

  Widget _buildLocationsOverviewCard(bool isDark, Map<String, dynamic> trip) {
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
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const AppText('DROP POINT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
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

    final driverCard = InkWell(
      onTap: () {
        Get.snackbar('Driver Profile', 'Driver details are up to date.', snackPosition: SnackPosition.BOTTOM);
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
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFD1FAE5),
              child: const Icon(Icons.person_rounded, color: Color(0xFF047857), size: 20),
            ),
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

  Widget _buildMilestonesTimeline(BuildContext context, bool isDark, List<Map<String, dynamic>> logs) {
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
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
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
              final label = log['label'] ?? 'Checkpoint';
              final timestamp = log['timestamp'] ?? '';
              final address = log['address'] ?? '';
              final lat = log['latitude'] ?? 0.0;
              final lng = log['longitude'] ?? 0.0;

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
                                        'GPS Coords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                        style: const TextStyle(
                                          color: Color(0xFF137333),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 22),
                  SizedBox(width: 10),
                  AppText(
                    'TRIP EXPENSE CLAIMS',
                    style: AppTextStyle.labelLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Get.snackbar('Add Expense', 'Add trip expense claims sheet is triggered.', snackPosition: SnackPosition.BOTTOM);
                },
                child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const Divider(height: 24),
          if (expensesList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.currency_rupee_rounded, size: 24, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const AppText('No Expenses Recorded', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    const SizedBox(height: 6),
                    AppText(
                      'There are currently no expense claims\nsubmitted for this trip.',
                      style: AppTextStyle.labelMedium,
                      color: Colors.grey.shade400,
                      textAlign: TextAlign.center,
                    ),
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
                final status = exp['status'] ?? 'Pending';
                final date = exp['date'] ?? '';

                Color statusColor = const Color(0xFFD97706);
                Color statusBg = const Color(0xFFFEF3C7);
                if (status == 'Approved') {
                  statusColor = const Color(0xFF047857);
                  statusBg = const Color(0xFFDCFCE7);
                } else if (status == 'Rejected') {
                  statusColor = const Color(0xFFDC2626);
                  statusBg = const Color(0xFFFEE2E2);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(title, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                            AppText(date, style: AppTextStyle.labelMedium, color: Colors.grey),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppText('₹$amt', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                            ),
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
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
              const SizedBox(width: 10),
              const Expanded(
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
                        color: Colors.black.withOpacity(0.6),
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
}
