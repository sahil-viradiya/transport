import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import '../../../data/services/session_service.dart';
import '../../../core/utils/document_viewer_helper.dart';
import '../../../core/utils/app_image_helper.dart';

/// Redesigned Journey Timeline screen:
/// - Compact top app bar with back button and clean title
/// - Trip summary card with status pill, driver/truck tags, and 2-column info grid
/// - Verification proofs card for photos, passes, and POD documents
/// - Journey milestones audit vertical timeline with green/orange status styling
/// - Fully responsive layout with multi-line wrapping and zero clipping
class TripStatusView extends GetView<TripDetailsController> {
  const TripStatusView({super.key});

  String _driverName() {
    try {
      final name = Get.find<SessionService>().name.value;
      return name.isEmpty ? 'Driver' : name;
    } catch (_) {
      return 'Driver';
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

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'DELIVERED':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D)); // Green
      case 'LOAD_REJECTED':
      case 'DELIVERY_REJECTED':
      case 'REJECTED':
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626)); // Red
      case 'LOAD_REQUESTED':
      case 'DELIVERY_REQUESTED':
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706)); // Orange/Amber
      case 'ACTIVE NOW':
      case 'EN_ROUTE_VENDOR':
      case 'LOADING':
      case 'ASSIGNED':
        return (const Color(0xFFEFF6FF), const Color(0xFF2563EB)); // Blue
      default:
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Journey Timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 1,
          ),
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Trip Summary Card
                _buildTripSummaryCard(context, isDark, status, data),
                const SizedBox(height: 14),

                // 2. Verification Proofs Panel (Photos & Documents)
                _buildVerificationProofsPanel(context, isDark, data),
                const SizedBox(height: 14),

                // 3. Real-time Journey Milestones Audit
                _buildMilestonesTimeline(context, isDark, status, items),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── 1. Trip Summary Card ───────────────────────────────────────────────────
  Widget _buildTripSummaryCard(
    BuildContext context,
    bool isDark,
    String status,
    Map<String, dynamic> data,
  ) {
    final (chipBg, chipFg) = _statusColors(status);
    final truckNo = (controller.vehicleNo.value.isNotEmpty)
        ? controller.vehicleNo.value
        : (data['truckNo'] ?? '—').toString();

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Top Row: Trip ID + Status Pill
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.tripId,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _friendlyStatus(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: chipFg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Driver & Truck Tags Row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 15,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Driver: ${_driverName()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 15,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Truck: $truckNo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              height: 1,
              thickness: 1,
            ),
          ),

          // 2-Column Info Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryField(
                  'MATERIAL',
                  (data['materialName'] ?? '—').toString(),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryField(
                  'ROYALTY OWNER',
                  (data['royaltyName'] ?? '—').toString(),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryField(
                  'LOADING PASS ID',
                  (data['loadingPassId'] ?? '—').toString(),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryField(
                  'PASS GENERATED AT',
                  (data['loadingPassGeneratedAt'] ?? '—').toString(),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryField(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.2,
          ),
          softWrap: true,
        ),
      ],
    );
  }

  // ── 2. Verification Proofs Panel ───────────────────────────────────────────
  Widget _buildVerificationProofsPanel(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> data,
  ) {
    final loadingPhotoUrl =
        (data['loadingPhotoUrl'] ?? data['loadingPhoto'] ?? '').toString();
    final gatePassPhotoUrl =
        (data['gatePassPhotoUrl'] ?? data['gatePassPhoto'] ?? '').toString();
    final passData = data['truckOwnerPassData'] as Map?;
    final truckOwnerPassId =
        (data['truckOwnerPassId'] ?? passData?['passId'] ?? '').toString();
    String truckOwnerPassUrl =
        (data['truckOwnerPassUrl'] ?? '').toString().trim();
    if (truckOwnerPassUrl.isEmpty && passData != null) {
      truckOwnerPassUrl = (passData['passPhotoUrl'] ??
              passData['passDocumentUrl'] ??
              passData['adminPhotoUrl'] ??
              passData['truckOwnerPassUrl'] ??
              '')
          .toString()
          .trim();
    }

    String destinationDocUrl =
        (data['destinationDocUrl'] ?? '').toString().trim();
    if (destinationDocUrl.isEmpty) {
      destinationDocUrl = (data['destinationPhotoUrl'] ??
              data['adminDocUrl'] ??
              data['adminPhotoUrl'] ??
              '')
          .toString()
          .trim();
    }
    final podUrl =
        (data['podPhotoUrl'] ?? data['podPhoto'] ?? data['podUrl'] ?? '')
            .toString();
    final remarks = (data['remarks'] ?? '').toString();

    final hasTruckOwnerPass = (data['hasTruckOwnerPass'] == true) ||
        truckOwnerPassId.isNotEmpty ||
        truckOwnerPassUrl.isNotEmpty ||
        passData != null;

    final hasLoadingProof =
        loadingPhotoUrl.isNotEmpty || gatePassPhotoUrl.isNotEmpty;
    final hasAdminProof = hasTruckOwnerPass || destinationDocUrl.isNotEmpty;
    final hasPodProof = podUrl.isNotEmpty;

    if (!hasLoadingProof && !hasAdminProof && !hasPodProof) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Section Header
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'VERIFICATION PROOFS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              height: 1,
              thickness: 1,
            ),
          ),

          // A. Loading Stage Proofs
          if (hasLoadingProof) ...[
            Text(
              'LOADING STAGE PROOFS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                if (loadingPhotoUrl.isNotEmpty)
                  _buildPhotoThumbnail(
                      context, loadingPhotoUrl, 'Loading Photo', isDark),
                if (gatePassPhotoUrl.isNotEmpty)
                  _buildPhotoThumbnail(
                      context, gatePassPhotoUrl, 'Gate Pass Photo', isDark),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // B. Truck Owner Pass & Admin Documents
          if (hasAdminProof) ...[
            Text(
              'TRUCK OWNER PASS & ADMIN DOCUMENTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                if (truckOwnerPassUrl.isNotEmpty)
                  _buildPhotoThumbnail(
                      context, truckOwnerPassUrl, 'Truck Owner Pass', isDark)
                else if (hasTruckOwnerPass)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF16A34A),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Truck Owner Pass Issued ✅',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFF15803D),
                                ),
                              ),
                              if (truckOwnerPassId.isNotEmpty)
                                Text(
                                  'Pass ID: #$truckOwnerPassId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              if (passData?['ownerName']?.toString().isNotEmpty == true)
                                Text(
                                  'Owner/Transporter: ${passData!['ownerName']}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (destinationDocUrl.isNotEmpty)
                  _buildPhotoThumbnail(
                      context, destinationDocUrl, 'Destination Doc/Photo', isDark),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // C. Proof of Delivery (POD)
          if (hasPodProof) ...[
            Text(
              'PROOF OF DELIVERY (POD)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            if (remarks.isNotEmpty) ...[
              Text(
                'REMARKS / NOTES',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  remarks,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildPhotoThumbnail(context, podUrl, 'POD Document', isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context,
    String url,
    String label,
    bool isDark,
  ) {
    final isPdf = DocumentViewerHelper.isPdf(url);

    Widget imageWidget;
    if (isPdf) {
      imageWidget = Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 28, color: Color(0xFFDC2626)),
            SizedBox(height: 4),
            Text(
              'PDF File',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      imageWidget = AppImageHelper.buildImageWidget(
        source: url,
        fit: BoxFit.cover,
        errorWidget: Container(
          color: isDark ? Colors.grey.shade900 : const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 22, color: Colors.grey),
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: imageWidget,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Journey Milestones Audit Vertical Timeline ───────────────────────────
  Widget _buildMilestonesTimeline(
    BuildContext context,
    bool isDark,
    String status,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDelivered = status == 'DELIVERED';

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Section Title
          Text(
            'JOURNEY MILESTONES AUDIT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 0.3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              height: 1,
              thickness: 1,
            ),
          ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLast = index == items.length - 1;
              final isLatest = isLast;

              final (nodeBg, nodeFg) = (isLatest && !isDelivered)
                  ? (const Color(0xFFFEF3C7), const Color(0xFFD97706)) // Active / In Progress
                  : (const Color(0xFFDCFCE7), const Color(0xFF15803D)); // Completed

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Dot Icon + Vertical Connector Line
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: nodeBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: nodeFg.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              (isLatest && !isDelivered)
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.check_rounded,
                              size: 13,
                              color: nodeFg,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Right Content: Label + Timestamp + Address
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 4 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['label'].toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      height: 1.25,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item['timestamp'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            if (item['address'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item['address'].toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                      softWrap: true,
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
      ),
    );
  }
}
