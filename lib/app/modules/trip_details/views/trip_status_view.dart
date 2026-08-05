import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/session_service.dart';
import '../../../core/utils/document_viewer_helper.dart';
import '../../../core/utils/image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
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

                const SizedBox(height: 8),

                // B. Verification Proofs Panel (Photos & Documents)
                _buildVerificationProofsPanel(context, isDark, data),

                const SizedBox(height: 16),

                // C. Real-time Activity Timeline List Section
                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: AppText(
                      'JOURNEY MILESTONES AUDIT',
                      style: AppTextStyle.labelMedium,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVerificationProofsPanel(BuildContext context, bool isDark, Map<String, dynamic> data) {
    final loadingPhotoUrl = (data['loadingPhotoUrl'] ?? data['loadingPhoto'] ?? '').toString();
    final gatePassPhotoUrl = (data['gatePassPhotoUrl'] ?? data['gatePassPhoto'] ?? '').toString();
    final passData = data['truckOwnerPassData'] as Map?;
    final truckOwnerPassId = (data['truckOwnerPassId'] ?? passData?['passId'] ?? '').toString();
    String truckOwnerPassUrl = (data['truckOwnerPassUrl'] ?? '').toString().trim();
    if (truckOwnerPassUrl.isEmpty && passData != null) {
      truckOwnerPassUrl = (passData['passPhotoUrl'] ??
              passData['passDocumentUrl'] ??
              passData['adminPhotoUrl'] ??
              passData['truckOwnerPassUrl'] ??
              '')
          .toString()
          .trim();
    }

    String destinationDocUrl = (data['destinationDocUrl'] ?? '').toString().trim();
    if (destinationDocUrl.isEmpty) {
      destinationDocUrl = (data['destinationPhotoUrl'] ??
              data['adminDocUrl'] ??
              data['adminPhotoUrl'] ??
              '')
          .toString()
          .trim();
    }
    final podUrl = (data['podPhotoUrl'] ?? data['podPhoto'] ?? data['podUrl'] ?? '').toString();
    final remarks = (data['remarks'] ?? '').toString();

    final hasTruckOwnerPass = (data['hasTruckOwnerPass'] == true) ||
        truckOwnerPassId.isNotEmpty ||
        truckOwnerPassUrl.isNotEmpty ||
        passData != null;

    final hasLoadingProof = loadingPhotoUrl.isNotEmpty || gatePassPhotoUrl.isNotEmpty;
    final hasAdminProof = hasTruckOwnerPass || destinationDocUrl.isNotEmpty;
    final hasPodProof = podUrl.isNotEmpty;

    if (!hasLoadingProof && !hasAdminProof && !hasPodProof) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'VERIFICATION PROOFS',
                  style: AppTextStyle.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // A. Loading Stage Proofs
          if (hasLoadingProof) ...[
            const AppText('LOADING STAGE PROOFS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 10),
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
            const SizedBox(height: 16),
          ],

          // B. Truck Owner Pass & Admin Documents
          if (hasAdminProof) ...[
            const AppText('TRUCK OWNER PASS & ADMIN DOCUMENTS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 10),
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
            const SizedBox(height: 16),
          ],

          // C. Proof of Delivery (POD)
          if (hasPodProof) ...[
            const AppText('PROOF OF DELIVERY (POD)', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 10),
            if (remarks.isNotEmpty) ...[
              const AppText('REMARKS / NOTES', style: AppTextStyle.labelMedium, color: Colors.grey),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: AppText(remarks, style: AppTextStyle.bodyMedium),
              ),
              const SizedBox(height: 12),
            ],
            _buildPhotoThumbnail(context, podUrl, 'POD Document', isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(BuildContext context, String url, String label, bool isDark) {
    final isPdf = DocumentViewerHelper.isPdf(url);

    Uint8List? base64Bytes;
    bool isBase64 = false;
    if (!isPdf && (url.startsWith('data:image') || (!url.startsWith('http') && !url.startsWith('/')))) {
      try {
        var str = url.trim();
        if (str.contains(',')) {
          str = str.split(',').last.trim();
        }
        str = str.replaceAll(RegExp(r'\s+'), '');
        while (str.length % 4 != 0) {
          str += '=';
        }
        base64Bytes = base64Decode(str);
        if (base64Bytes.isNotEmpty) {
          isBase64 = true;
        }
      } catch (_) {}
    }

    Widget imageWidget;
    if (isPdf) {
      imageWidget = Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 32, color: Colors.redAccent),
            SizedBox(height: 4),
            Text('PDF File', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (isBase64 && base64Bytes != null) {
      imageWidget = Image.memory(
        base64Bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey),
          ),
        ),
      );
    } else if (url.startsWith('/')) {
      imageWidget = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey),
          ),
        ),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: corsSafeImageUrl(url),
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Container(
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
            width: 90,
            height: 90,
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
}
