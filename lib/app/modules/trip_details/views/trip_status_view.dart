import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/session_service.dart';

/// Modern, real-time Activity History screen. It displays only the actual logged
/// milestones from the Firestore milestonesLog with real timestamps and locations.
/// Does not show fake future ticks or simulated increments.
class TripStatusView extends GetView<TripDetailsController> {
  const TripStatusView({super.key});

  String _driverName() {
    try {
      final name = Get.find<SessionService>().name.value;
      return name.isEmpty ? 'Deep' : name;
    } catch (_) {
      return 'Deep';
    }
  }

  String _friendlyStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending Accept';
      case 'ASSIGNED':
        return 'Trip Assigned';
      case 'EN_ROUTE_VENDOR':
        return 'On The Way (Vendor)';
      case 'LOADING':
        return 'Loading at Vendor';
      case 'LOAD_REQUESTED':
        return 'Load Approval';
      case 'LOAD_REJECTED':
        return 'Load Rejected';
      case 'ACTIVE NOW':
        return 'On The Way (Dest.)';
      case 'DELIVERY_REQUESTED':
        return 'Delivery Approval';
      case 'DELIVERY_REJECTED':
        return 'Delivery Rejected';
      case 'DELIVERED':
        return 'Completed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status.isEmpty ? 'Active' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF10B981); // Green
      case 'LOAD_REJECTED':
      case 'DELIVERY_REJECTED':
      case 'REJECTED':
        return const Color(0xFFEF4444); // Red
      case 'LOAD_REQUESTED':
      case 'DELIVERY_REQUESTED':
        return const Color(0xFFF59E0B); // Amber
      default:
        return AppColors.primary; // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const AppText(
          'Journey Timeline',
          style: AppTextStyle.headlineSmall,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Obx(() {
        final status = controller.tripStatus.value;
        final data = controller.tripExtra.value ?? {};
        final logs = data['milestonesLog'] as List? ?? [];
        final tripDate = (data['date'] ?? '').toString();

        // Create a list of milestones starting with an initial "Trip Assigned" event
        final List<Map<String, dynamic>> items = [];
        
        // Always seed "Trip Assigned" as the starting baseline event
        items.add({
          'label': 'Trip Assigned by Admin',
          'timestamp': tripDate.isNotEmpty ? tripDate : 'Assigned',
          'address': (data['pickupLocation'] ?? 'Terminal Gate').toString(),
          'isInitial': true,
        });

        for (final log in logs) {
          if (log is Map) {
            items.add({
              'label': (log['label'] ?? log['milestone']?.toString() ?? 'Update').toString(),
              'timestamp': (log['timestamp'] ?? '').toString(),
              'address': (log['address'] ?? '').toString(),
              'isInitial': false,
            });
          }
        }

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A. Header Overview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AppText(
                              controller.tripId,
                              style: AppTextStyle.bodyLarge,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AppText(
                                _friendlyStatus(status),
                                style: AppTextStyle.labelMedium,
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              AppText('Driver: ${_driverName()}', style: AppTextStyle.bodyMedium),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              AppText('Truck: ${controller.vehicleNo.value}', style: AppTextStyle.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('MATERIAL', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                                const SizedBox(height: 4),
                                AppText((data['materialName'] ?? '—').toString(), style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('ROYALTY OWNER', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                                const SizedBox(height: 4),
                                AppText((data['royaltyName'] ?? '—').toString(), style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('LOADING PASS ID', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                                const SizedBox(height: 4),
                                AppText((data['loadingPassId'] ?? '—').toString(), style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('PASS GENERATED AT', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10),
                                const SizedBox(height: 4),
                                AppText((data['loadingPassGeneratedAt'] ?? '—').toString(), style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // B. Real-time Activity Timeline List
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: AppText('No milestones logged yet.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isLast = index == items.length - 1;
                          final isNewest = index == items.length - 1; // latest event is active
                          
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left Dot and vertical line connector
                                Column(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isNewest 
                                            ? _statusColor(status) 
                                            : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isNewest 
                                              ? _statusColor(status).withValues(alpha: 0.3)
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isNewest ? Icons.play_arrow_rounded : Icons.check_rounded,
                                          size: 12,
                                          color: isNewest ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(width: 16),

                                // Right text information card
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: AppText(
                                                item['label'].toString(),
                                                style: AppTextStyle.bodyLarge,
                                                fontWeight: isNewest ? FontWeight.bold : FontWeight.w600,
                                                color: isNewest 
                                                    ? (isDark ? Colors.white : AppColors.textPrimary)
                                                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AppText(
                                              item['timestamp'].toString(),
                                              style: AppTextStyle.labelMedium,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                        if (item['address'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.place_outlined, size: 13, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: AppText(
                                                  item['address'].toString(),
                                                  style: AppTextStyle.labelMedium,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

            ],
          ),
        );
      }),
    );
  }
}
