import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import 'trip_status_view.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/session_service.dart';
import '../../../core/utils/document_viewer_helper.dart';
import '../../../core/utils/app_image_helper.dart';

class TripDetailsView extends GetView<TripDetailsController> {
  const TripDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      if (!controller.isJourneyStarted.value) {
        return _buildStartConfirmationView(context, isDark);
      } else {
        return _buildActiveTrackingView(context, isDark);
      }
    });
  }

  // SCREEN 1: Trip Details (reference design — info + Call Admin + Update Status)
  Widget _buildStartConfirmationView(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const AppText('Trip Details',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        final ex = controller.tripExtra.value ?? {};
        final status = controller.tripStatus.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card: id + assigned-on + status chip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(controller.tripId,
                              style: AppTextStyle.headlineSmall,
                              fontWeight: FontWeight.w800),
                          const SizedBox(height: 2),
                          AppText(
                              'Assigned On ${controller.departureTime.value}',
                              style: AppTextStyle.labelMedium),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(_friendlyStatus(status),
                          style: AppTextStyle.labelMedium,
                          color: AppColors.info,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Key-value details card (vendor / material / pass info)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? Colors.white10 : AppColors.border),
                ),
                child: Column(
                  children: [
                    _kv('Vendor Name', (ex['vendorName'] ?? '—').toString()),
                    _kv('Vendor Location',
                        (ex['vendorLocation'] ?? '—').toString()),
                    _kv('Material Name',
                        (ex['materialName'] ?? '—').toString()),
                    _kv('Product Name', (ex['productName'] ?? '—').toString()),
                    _kv('Truck Number', controller.vehicleNo.value),
                    _kv('Driver Name', _driverDisplayName()),
                    _kv('Pickup Location',
                        (ex['pickupLocation'] ?? ex['vendorLocation'] ?? '—').toString()),
                    _kv('Pickup District',
                        (ex['pickupDistrict'] ?? '—').toString()),
                    _kv('Pass Holder Name',
                        (ex['passHolderName'] ?? '—').toString()),
                    _kv('Royalty Name', (ex['royaltyName'] ?? '—').toString()),
                    _kv(
                        'Loading Pass ID',
                        (ex['loadingPassId'] ?? '').toString().isEmpty
                            ? '—'
                            : '${ex['loadingPassId']} (8 digit)'),
                    _kv('Min Pass ID', (ex['minPassId'] ?? '—').toString()),
                    _kv('Max Pass ID', (ex['maxPassId'] ?? '—').toString(),
                        last: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Uploaded Trip Documents Card (Photos & PDFs view & download)
              _buildTripDocumentsCard(context, isDark, ex),
              const SizedBox(height: 20),

              // Actions: Call Admin + Update Status
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.callAdmin,
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call Admin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Obx(() {
                    final status = controller.tripStatus.value;
                    final isActionable = status != 'PENDING' && status != 'DELIVERED' && status != 'REJECTED';
                    if (!isActionable) return const SizedBox.shrink();
                    return Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.to(() => const TripStatusView()),
                              icon: const Icon(Icons.published_with_changes_rounded,
                                  size: 18),
                              label: const Text('Update Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  String _friendlyStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending Accept';
      case 'ASSIGNED':
        return 'Accepted';
      case 'EN_ROUTE_VENDOR':
        return 'On The Way';
      case 'LOADING':
        return 'Loading';
      case 'LOAD_REQUESTED':
        return 'Load Requested';
      case 'ACTIVE NOW':
        return 'On The Way (Dest.)';
      case 'DELIVERY_REQUESTED':
        return 'Delivery Requested';
      case 'DELIVERED':
        return 'Completed';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  String _driverDisplayName() {
    try {
      final name = Get.find<SessionService>().name.value;
      return name.isEmpty ? '—' : name;
    } catch (_) {
      return '—';
    }
  }

  Widget _kv(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppText(label,
                style: AppTextStyle.bodyMedium, color: AppColors.textSecondary),
          ),
          Expanded(
            flex: 3,
            child: AppText(value,
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

  Widget _buildTripDocumentsCard(
      BuildContext context, bool isDark, Map<String, dynamic> ex) {
    final loadingPhotoUrl = (ex['loadingPhotoUrl'] ?? ex['loadingPhoto'] ?? '').toString();
    final gatePassPhotoUrl = (ex['gatePassPhotoUrl'] ?? ex['gatePassPhoto'] ?? '').toString();
    final passData = ex['truckOwnerPassData'] as Map?;
    final truckOwnerPassId = (ex['truckOwnerPassId'] ?? passData?['passId'] ?? '').toString();
    String truckOwnerPassUrl = (ex['truckOwnerPassUrl'] ?? '').toString().trim();
    if (truckOwnerPassUrl.isEmpty && passData != null) {
      truckOwnerPassUrl = (passData['passPhotoUrl'] ??
              passData['passDocumentUrl'] ??
              passData['adminPhotoUrl'] ??
              passData['truckOwnerPassUrl'] ??
              '')
          .toString()
          .trim();
    }

    String destinationDocUrl = (ex['destinationDocUrl'] ?? '').toString().trim();
    if (destinationDocUrl.isEmpty) {
      destinationDocUrl = (ex['destinationPhotoUrl'] ??
              ex['adminDocUrl'] ??
              ex['adminPhotoUrl'] ??
              '')
          .toString()
          .trim();
    }
    final podUrl = (ex['podPhotoUrl'] ?? ex['podPhoto'] ?? ex['podUrl'] ?? '').toString();
    final remarks = (ex['remarks'] ?? '').toString();

    final hasTruckOwnerPass = (ex['hasTruckOwnerPass'] == true) ||
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
                  _buildPhotoTile(context, loadingPhotoUrl, 'Loading Photo', isDark),
                  const SizedBox(width: 12),
                ],
                if (gatePassPhotoUrl.isNotEmpty) ...[
                  _buildPhotoTile(context, gatePassPhotoUrl, 'Gate Pass Photo', isDark),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],

          // B. Truck Owner Pass & Admin Documents Section
          if (hasAdminProof) ...[
            const AppText('TRUCK OWNER PASS & ADMIN DOCUMENTS', style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold, color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (truckOwnerPassUrl.isNotEmpty) ...[
                  _buildPhotoTile(context, truckOwnerPassUrl, 'Truck Owner Pass', isDark),
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
                  _buildPhotoTile(context, destinationDocUrl, 'Destination Doc/Photo', isDark),
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
            _buildPhotoTile(context, podUrl, 'POD Document', isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoTile(BuildContext context, String url, String label, bool isDark) {
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

  // SCREEN 2: Active Trip Tracking
  Widget _buildActiveTrackingView(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFF09202F), // Slate contours gradient base
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: AppText('app_title'.tr,
            style: AppTextStyle.headlineSmall,
            color: Colors.white,
            fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2838), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A. Top Indicators Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left status and sync stack
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const AppText('GPS Live Sync',
                                  style: AppTextStyle.labelMedium,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Obx(() => AppText(
                                'Last synced: ${controller.lastSynced.value}',
                                style: AppTextStyle.labelMedium,
                                color: Colors.white70,
                              )),
                        ),
                        const SizedBox(height: 8),
                        Obx(() => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Colors.redAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: AppText(
                                      controller.currentAddress.value,
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.white70,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right circular Speed Gauge
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.speed_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(height: 2),
                          Obx(() => AppText(
                                '${controller.speed.value}',
                                style: AppTextStyle.headlineSmall,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              )),
                          const AppText('KM/H',
                              style: AppTextStyle.labelMedium,
                              color: Colors.white54,
                              fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // B. Active Trip Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(controller.vehicleNo.value,
                                  style: AppTextStyle.bodyLarge,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold),
                              AppText(
                                  'Route: ${controller.departureTitle.value} ➔ ${controller.destinationTitle.value}',
                                  style: AppTextStyle.labelMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('NEXT STOP ETA',
                                  style: AppTextStyle.labelMedium),
                              const SizedBox(height: 2),
                              Obx(() => AppText(
                                    controller.estimatedTime.value,
                                    style: AppTextStyle.headlineLarge,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const AppText('REMAINING',
                                  style: AppTextStyle.labelMedium),
                              const SizedBox(height: 2),
                              Obx(() => AppText(
                                    controller.remainingDistance.value,
                                    style: AppTextStyle.headlineLarge,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thick Journey Progress Bar
                    Obx(() {
                      // Mock progress value based on current milestone state
                      double progressVal = 0.35;
                      if (controller.currentMilestone.value == 2) {
                        progressVal = 0.65;
                      }
                      if (controller.currentMilestone.value > 2) {
                        progressVal = 1.0;
                      }

                      return LinearProgressIndicator(
                        value: progressVal,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                            '${controller.departureTitle.value.split(' ').first} (Started)',
                            style: AppTextStyle.labelMedium),
                        AppText(
                            '${controller.destinationTitle.value.split(' ').first} (Destination)',
                            style: AppTextStyle.labelMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // C. Milestone Action Cards (Reached Pickup, Loaded, Reached Drop)
              _buildMilestoneActionCard(
                index: 1,
                icon: Icons.location_on_outlined,
                label: 'Reached Pickup',
              ),
              const SizedBox(height: 12),
              _buildMilestoneActionCard(
                index: 2,
                icon: Icons.inventory_2_outlined,
                label: 'Loaded',
              ),
              const SizedBox(height: 12),
              _buildMilestoneActionCard(
                index: 3,
                icon: Icons.check_circle_outline_rounded,
                label: 'Reached Drop',
              ),
              const SizedBox(height: 16),
              Obx(() => _buildTripDocumentsCard(
                  context, isDark, controller.tripExtra.value ?? {})),
              _buildPODDetailsCard(context, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPODDetailsCard(BuildContext context, bool isDark) {
    return Obx(() {
      final hasPod = controller.currentMilestone.value == 4;
      if (!hasPod) return const SizedBox.shrink();

      final imgPath = controller.podUrl.value;
      final remarksText = controller.remarks.value;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                const AppText(
                  'PROOF OF DELIVERY SUBMITTED',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ],
            ),
            const Divider(height: 24),
            if (remarksText.isNotEmpty) ...[
              const AppText(
                'REMARKS / NOTES',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 6),
              AppText(
                remarksText,
                style: AppTextStyle.bodyMedium,
                color: isDark ? Colors.white70 : AppColors.secondary,
              ),
              const SizedBox(height: 16),
            ],
            if (imgPath.isNotEmpty) ...[
              const AppText(
                'DELIVERY RECEIPT PHOTO',
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => DocumentViewerHelper.showDocument(context, imgPath, title: 'POD Document'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: AppImageHelper.buildImageWidget(
                      source: imgPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // Interactive milestone cards for Active Trip Tracking view
  Widget _buildMilestoneActionCard({
    required int index,
    required IconData icon,
    required String label,
  }) {
    return Obx(() {
      final dbMilestone = controller.currentMilestone.value;
      final activeMilestone = dbMilestone == 0 ? 1 : dbMilestone;
      final isCompleted = index < activeMilestone;
      final isActive = index == activeMilestone;

      // Solid blue style if active (needs action)
      if (isActive) {
        return GestureDetector(
          onTap: () => controller.selectMilestone(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                AppText(label,
                    style: AppTextStyle.bodyLarge,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ],
            ),
          ),
        );
      }

      // Completed check state styling (white card, green/grey check)
      if (isCompleted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 22),
              const SizedBox(width: 10),
              AppText(label,
                  style: AppTextStyle.bodyLarge,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
            ],
          ),
        );
      }

      // Locked/disabled state (unreached milestone yet)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 22),
            const SizedBox(width: 10),
            AppText(label,
                style: AppTextStyle.bodyLarge, color: Colors.grey.shade400),
          ],
        ),
      );
    });
  }
}
