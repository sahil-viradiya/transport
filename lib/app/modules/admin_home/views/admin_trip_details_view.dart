import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transport/widgets/app_button.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/widgets/trip_progress_tracker.dart';
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
      appBar: AppBar(
        title: AppText(
          'Trip Details - $tripId',
          style: AppTextStyle.headlineSmall,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
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

        final isTripActive = trip['isActive'] == true;
        final isDelivered = trip['status'] == 'DELIVERED';
        final driverPhone = trip['driverPhone'] ?? 'N/A';
        final driverName = controller.users.firstWhereOrNull(
              (u) => u['phone'] == driverPhone,
            )?['name'] ??
            'Assigned Driver';

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
          // Fallback: Generate mock history logs based on current status and coordinates
          final currentMilestone = trip['currentMilestone'] as int? ?? 0;
          final tripDate = trip['date'] ?? '24 Oct, 08:30 AM';

          logs.add({
            'milestone': 1,
            'label': 'Trip Assigned',
            'timestamp': tripDate,
            'address': trip['pickupLocation'] ?? 'JNPT Terminal',
            'latitude': trip['pickupLatitude'] ?? 18.9482,
            'longitude': trip['pickupLongitude'] ?? 72.9469,
          });

          if (currentMilestone >= 2) {
            logs.add({
              'milestone': 2,
              'label': 'Reached Pickup',
              'timestamp': '24 Oct, 09:45 AM',
              'address': trip['pickupLocation'] ?? 'JNPT Terminal',
              'latitude': trip['pickupLatitude'] ?? 18.9482,
              'longitude': trip['pickupLongitude'] ?? 72.9469,
            });
          }

          if (currentMilestone >= 3) {
            logs.add({
              'milestone': 3,
              'label': 'Loaded',
              'timestamp': '24 Oct, 11:30 AM',
              'address': trip['pickupLocation'] ?? 'JNPT Terminal',
              'latitude': trip['pickupLatitude'] ?? 18.9482,
              'longitude': trip['pickupLongitude'] ?? 72.9469,
            });
          }

          if (currentMilestone >= 4 || trip['status'] == 'DELIVERED') {
            logs.add({
              'milestone': 4,
              'label': 'Reached Drop / Delivered',
              'timestamp': '24 Oct, 09:15 PM',
              'address': trip['dropLocation'] ?? 'Mihan Hub',
              'latitude': trip['dropLatitude'] ?? 21.0792,
              'longitude': trip['dropLongitude'] ?? 79.0274,
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
              // Header Summary Card
              _buildTripOverviewHeader(context, isDark, trip, isTripActive, isDelivered),
              const SizedBox(height: 20),

              // Driver & Vehicle Card
              _buildTripMetadataCard(isDark, trip, driverName, driverPhone),
              const SizedBox(height: 24),

              // Multi-column or Stacked Layout
              if (isWebOrDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildMilestonesTimeline(context, isDark, logs),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTripExpensesPanel(context, isDark, tripExpenses),
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
                _buildTripExpensesPanel(context, isDark, tripExpenses),
                if (isDelivered) ...[
                  const SizedBox(height: 24),
                  _buildPODDetailsPanel(context, isDark, trip),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTripOverviewHeader(BuildContext context, bool isDark, Map<String, dynamic> trip, bool isTripActive, bool isDelivered) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText(
                        'TRIP ID: ${trip['id']}',
                        style: AppTextStyle.headlineSmall,
                        fontWeight: FontWeight.w800,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isTripActive
                              ? const Color(0xFFFFF0B3)
                              : (isDelivered
                                  ? const Color(0xFFE3FCEF)
                                  : AppColors.primaryLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AppText(
                          trip['status'] ?? 'ASSIGNED',
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
                    'Route: ${trip['pickupCity']} ➔ ${trip['dropCity']}',
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                onPressed: () async {
                  final confirm = await Get.dialog<bool>(
                    AlertDialog(
                      title: const Text('Delete Trip?'),
                      content: Text('Are you sure you want to delete trip ${trip['id']}? This action is irreversible.'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Get.back(result: true),
                          child: const Text('Delete', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    controller.deleteTrip(trip['id']);
                    Get.back();
                  }
                },
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('PICKUP POINT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                    const SizedBox(height: 4),
                    AppText(trip['pickupCity'] ?? '', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    AppText(trip['pickupLocation'] ?? '', style: AppTextStyle.labelMedium, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppColors.primary.withOpacity(0.5)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const AppText('DROP POINT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                    const SizedBox(height: 4),
                    AppText(trip['dropCity'] ?? '', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    AppText(trip['dropLocation'] ?? '', style: AppTextStyle.labelMedium, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          TripProgressTracker(trip: trip, showSummary: false),
        ],
      ),
    );
  }

  Widget _buildTripMetadataCard(bool isDark, Map<String, dynamic> trip, String driverName, String driverPhone) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  radius: 24,
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('DRIVER PROFILE', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                      const SizedBox(height: 4),
                      AppText(driverName, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                      AppText(driverPhone, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  radius: 24,
                  child: const Icon(Icons.local_shipping_rounded, color: AppColors.secondary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('VEHICLE ASSIGNED', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
                      const SizedBox(height: 4),
                      AppText(trip['truckNo'] ?? 'N/A', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                      AppText(
                        trip['currentAddress']?.isNotEmpty == true
                            ? 'GPS Tracking En Route'
                            : 'Sync Status: Awaiting GPS...',
                        style: AppTextStyle.labelMedium,
                        color: AppColors.textSecondary,
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

  Widget _buildMilestonesTimeline(BuildContext context, bool isDark, List<Map<String, dynamic>> logs) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 24),
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
                    // 1. Time Column
                    SizedBox(
                      width: 76,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppText(
                          _formatTimeOnly(timestamp),
                          style: AppTextStyle.labelMedium,
                          color: isDark ? Colors.white54 : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Icon & connector Column
                    Column(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
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
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 72,
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // 3. Content Card Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              label,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 6),
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
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                AppText(
                                  'GPS Coords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                  style: AppTextStyle.labelMedium,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                    _openInMaps(mapsUrl);
                                  },
                                  icon: const Icon(Icons.map_rounded, size: 14),
                                  label: const Text('Open Maps', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTripExpensesPanel(BuildContext context, bool isDark, List<Map<String, dynamic>> expensesList) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.receipt_long_rounded, color: AppColors.secondary, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: AppText(
                  'TRIP EXPENSE CLAIMS',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (expensesList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.currency_rupee_rounded, size: 48, color: AppColors.textHint),
                    SizedBox(height: 12),
                    AppText('No expense claims recorded for this trip.', style: AppTextStyle.bodyMedium),
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
                final desc = exp['description'] ?? '';
                final status = exp['status'] ?? 'Pending';
                final receiptUrl = exp['receiptUrl'] ?? '';
                final date = exp['date'] ?? '';
                final expAddress = exp['locationName'] ?? '';
                final expLat = exp['latitude'];
                final expLng = exp['longitude'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            title.contains('Fuel')
                                ? Icons.local_gas_station_rounded
                                : Icons.receipt_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppText(
                              title,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(amt, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.w800),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (desc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AppText(desc, style: AppTextStyle.bodyMedium),
                        ),
                      AppText('Logged on: $date', style: AppTextStyle.labelMedium, color: AppColors.textHint),

                      if (expAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(expAddress, style: AppTextStyle.labelMedium),
                                  if (expLat != null && expLng != null)
                                    AppText(
                                      'GPS: ${expLat.toStringAsFixed(5)}, ${expLng.toStringAsFixed(5)}',
                                      style: AppTextStyle.labelMedium,
                                      color: AppColors.textHint,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'Approved'
                                  ? const Color(0xFFE3FCEF)
                                  : (status == 'Rejected'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFFF0B3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AppText(
                              status,
                              style: AppTextStyle.labelMedium,
                              color: status == 'Approved'
                                  ? const Color(0xFF006644)
                                  : (status == 'Rejected'
                                      ? AppColors.error
                                      : const Color(0xFFBF2600)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              if (receiptUrl.isNotEmpty) ...[
                                TextButton.icon(
                                  onPressed: () {
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
                                                _getCorsWebUrl(receiptUrl),
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
                                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                  label: const AppText('View Receipt', style: AppTextStyle.labelMedium, color: AppColors.primary),
                                ),
                              ],
                              if (status == 'Pending') ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => controller.approveExpense(exp),
                                  child: const AppText('Approve',
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => controller.rejectExpense(exp),
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

  Widget _buildPODDetailsPanel(BuildContext context, bool isDark, Map<String, dynamic> trip) {
    final remarks = trip['remarks'] ?? 'No delivery comments left.';
    final podUrl = trip['podUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 24),
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
          const AppText('DRIVER REMARKS / NOTES', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: AppText(remarks, style: AppTextStyle.bodyMedium),
          ),
          const SizedBox(height: 20),

          if (podUrl.isNotEmpty) ...[
            const AppText('SCANNED DOCUMENT PREVIEW', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
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
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
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
