import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transport/app/routes/app_pages.dart';
import '../controllers/trips_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';

/// A 4-step loading workflow widget shown inside the trip card for active
/// trips (ASSIGNED → EN_ROUTE_VENDOR → LOADING → LOAD_REQUESTED → ACTIVE NOW).
class DriverLoadingWorkflow extends StatefulWidget {
  final TripItemModel trip;
  const DriverLoadingWorkflow({super.key, required this.trip});

  @override
  State<DriverLoadingWorkflow> createState() => _DriverLoadingWorkflowState();
}

class _DriverLoadingWorkflowState extends State<DriverLoadingWorkflow> {
  Uint8List? _loadingPhotoBytes;
  Uint8List? _gatePassPhotoBytes;

  /// Maps trip status to step index (0-based).
  int get _currentStep {
    switch (widget.trip.status) {
      case 'ASSIGNED':
        return 0;
      case 'EN_ROUTE_VENDOR':
        return 1;
      case 'LOADING':
      case 'LOAD_REJECTED':
        return 2;
      case 'LOAD_REQUESTED':
        return 3; // waiting for admin
      case 'ACTIVE NOW':
      case 'DELIVERY_REQUESTED':
      case 'DELIVERY_REJECTED':
      case 'DELIVERED':
        return 4; // all done
      default:
        return 0;
    }
  }

  Future<Uint8List?> _capturePhotoFromCamera() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x != null) {
        return await x.readAsBytes();
      }
    } catch (e) {
      Get.snackbar('Camera Error', e.toString());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = Get.find<TripsController>();
    final step = _currentStep;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 20,
                color: isDark ? const Color(0xFF93C5FD) : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: AppText(
                  'Loading Workflow',
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText(
                  'Step ${step.clamp(1, 4)} of 4',
                  style: AppTextStyle.labelMedium,
                  color: isDark ? Colors.white60 : const Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 1: Start Trip
          _StepTile(
            stepNumber: 1,
            title: 'Start Trip',
            subtitle: step > 0
                ? 'Trip started successfully'
                : 'Vendor ke liye nikal jayein',
            isCompleted: step > 0,
            isCurrent: step == 0,
            isLocked: false,
            isDark: isDark,
            actionLabel: 'Start Trip',
            actionIcon: Icons.play_arrow_rounded,
            actionColor: AppColors.primary,
            onAction:
                step == 0 ? () => controller.startTrip(widget.trip.id) : null,
          ),
          _buildConnector(isDark, step > 0),

          // Step 2: Reach for Loading
          _StepTile(
            stepNumber: 2,
            title: 'Reach for Loading',
            subtitle: step > 1
                ? 'Loading point par pahunch gaye'
                : 'Tap when truck reaches loading point',
            isCompleted: step > 1,
            isCurrent: step == 1,
            isLocked: step < 1,
            isDark: isDark,
            actionLabel: 'Mark Reached',
            actionIcon: Icons.location_on_rounded,
            actionColor: const Color(0xFF3B82F6),
            onAction: step == 1
                ? () => controller.markReachedLoading(widget.trip.id)
                : null,
          ),
          _buildConnector(isDark, step > 1),

          // Step 3: Truck Loaded (Photos Required)
          _StepTile(
            stepNumber: 3,
            title: 'Truck Loaded',
            subtitle: widget.trip.status == 'LOAD_REJECTED'
                ? 'Rejected: Verification failed. Re-upload required.'
                : step > 2
                    ? (step == 3
                        ? 'Photos submitted — waiting for admin approval'
                        : 'Admin ne loading approve kar di')
                    : 'Loading & Gate Pass photo click karein',
            isCompleted: step > 3,
            isCurrent: step == 2,
            isLocked: step < 2,
            isWaiting: step == 3,
            isDark: isDark,
            actionLabel: widget.trip.status == 'LOAD_REJECTED'
                ? 'Re-upload Flagged'
                : 'Mark Loaded',
            actionIcon: Icons.camera_alt_rounded,
            actionColor: widget.trip.status == 'LOAD_REJECTED'
                ? const Color(0xFFDC2626)
                : const Color(0xFFF59E0B),
            customContent:
                step == 2 ? _buildStep3Content(controller, isDark) : null,
          ),
          _buildConnector(isDark, step > 3),

          // Step 4: Deliver & Submit POD
          _StepTile(
            stepNumber: 4,
            title: 'Deliver & Submit POD',
            subtitle: widget.trip.status == 'DELIVERED'
                ? 'Delivered successfully'
                : widget.trip.status == 'DELIVERY_REQUESTED'
                    ? 'Proof submitted — waiting for admin approval'
                    : widget.trip.status == 'DELIVERY_REJECTED'
                        ? 'Rejected: Reupload proof required'
                        : widget.trip.status == 'ACTIVE NOW'
                            ? 'Upload proof of delivery at destination'
                            : 'Destination unlocks after approval',
            isCompleted: widget.trip.status == 'DELIVERED',
            isCurrent: widget.trip.status == 'ACTIVE NOW' || widget.trip.status == 'DELIVERY_REJECTED',
            isWaiting: widget.trip.status == 'DELIVERY_REQUESTED',
            isLocked: step < 4,
            isDark: isDark,
            actionLabel: widget.trip.status == 'DELIVERED'
                ? 'Completed'
                : widget.trip.status == 'DELIVERY_REQUESTED'
                    ? 'Pending Approval'
                    : widget.trip.status == 'DELIVERY_REJECTED'
                        ? 'Re-submit Proof of Delivery'
                        : widget.trip.status == 'ACTIVE NOW'
                            ? 'Submit Proof of Delivery'
                            : 'Locked',
            actionIcon: widget.trip.status == 'DELIVERED'
                ? Icons.check_circle_rounded
                : widget.trip.status == 'DELIVERY_REQUESTED'
                    ? Icons.hourglass_empty_rounded
                    : (widget.trip.status == 'ACTIVE NOW' || widget.trip.status == 'DELIVERY_REJECTED')
                        ? Icons.upload_file_rounded
                        : Icons.lock_rounded,
            actionColor: widget.trip.status == 'DELIVERY_REJECTED'
                ? const Color(0xFFDC2626)
                : const Color(0xFF10B981),
            onAction: (widget.trip.status == 'ACTIVE NOW' || widget.trip.status == 'DELIVERY_REJECTED')
                ? () {
                    Get.toNamed(
                      Routes.PROOF_OF_DELIVERY,
                      arguments: {'tripId': widget.trip.id},
                    )?.then((value) {
                      if (value == true) {
                        controller.fetchTripsFromFirebase();
                      }
                    });
                  }
                : null,
            customContent: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.trip.status == 'DELIVERY_REJECTED') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFDC2626), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Delivery Proof Rejected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${widget.trip.deliveryRejectReason}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if ({'ACTIVE NOW', 'DELIVERY_REQUESTED', 'DELIVERED', 'DELIVERY_REJECTED'}.contains(widget.trip.status)) ...[
                  if (widget.trip.hasTruckOwnerPass) ...[
                    _buildTruckOwnerPassCard(isDark),
                    _buildDestinationInfoCard(isDark),
                  ] else ...[
                    _buildAwaitingTruckOwnerPassCard(isDark),
                  ],
                ] else if (widget.trip.status == 'LOAD_REQUESTED') ...[
                  _buildAwaitingTruckOwnerPassCard(isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isDark, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF10B981)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildStep3Content(TripsController controller, bool isDark) {
    final needsLoading = widget.trip.status != 'LOAD_REJECTED' ||
        widget.trip.flaggedPhoto == 'loading' ||
        widget.trip.flaggedPhoto == 'both';
    final needsGatePass = widget.trip.status != 'LOAD_REJECTED' ||
        widget.trip.flaggedPhoto == 'gate_pass' ||
        widget.trip.flaggedPhoto == 'both';

    final hasLoading = _loadingPhotoBytes != null;
    final hasGatePass = _gatePassPhotoBytes != null;

    final isSubmitEnabled = (!needsLoading || hasLoading) && (!needsGatePass || hasGatePass);

    String buttonLabel = 'Submit Load & Gate Pass';
    if (widget.trip.status == 'LOAD_REJECTED') {
      if (needsLoading && !needsGatePass) {
        buttonLabel = 'Resubmit Loading Photo';
      } else if (!needsLoading && needsGatePass) {
        buttonLabel = 'Resubmit Gate Pass Photo';
      } else {
        buttonLabel = 'Resubmit Both Photos';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.trip.status == 'LOAD_REJECTED') ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Rejected - Reupload Required',
                        style: AppTextStyle.bodyMedium,
                        color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  'Reason: ${widget.trip.loadRejectReason}',
                  style: AppTextStyle.bodyMedium,
                  color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                ),
                if (widget.trip.flaggedPhoto != 'both') ...[
                  const SizedBox(height: 4),
                  AppText(
                    'Required: Only re-upload ${widget.trip.flaggedPhoto == 'loading' ? 'Loading Photo' : 'Gate Pass Photo'}',
                    style: AppTextStyle.bodyMedium,
                    color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: needsLoading
                    ? () async {
                        final bytes = await _capturePhotoFromCamera();
                        if (bytes != null) {
                          setState(() {
                            _loadingPhotoBytes = bytes;
                          });
                        }
                      }
                    : null,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !needsLoading
                          ? const Color(0xFF10B981)
                          : hasLoading
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: 1.5,
                    ),
                  ),
                  child: !needsLoading
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.5),
                                child: widget.trip.loadingPhotoUrl != null &&
                                        widget.trip.loadingPhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        widget.trip.loadingPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(10.5),
                                    bottomRight: Radius.circular(10.5),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: const Text(
                                  'Photo OK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : hasLoading
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10.5),
                                    child: Image.memory(
                                      _loadingPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 12),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10.5),
                                        bottomRight: Radius.circular(10.5),
                                      ),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: const Text(
                                      'Retake',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey.shade600,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                const AppText(
                                  'Loading Photo',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold,
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  'Click to take',
                                  style: AppTextStyle.labelMedium,
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.grey.shade400,
                                ),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: needsGatePass
                    ? () async {
                        final bytes = await _capturePhotoFromCamera();
                        if (bytes != null) {
                          setState(() {
                            _gatePassPhotoBytes = bytes;
                          });
                        }
                      }
                    : null,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !needsGatePass
                          ? const Color(0xFF10B981)
                          : hasGatePass
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: 1.5,
                    ),
                  ),
                  child: !needsGatePass
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.5),
                                child: widget.trip.gatePassPhotoUrl != null &&
                                        widget.trip.gatePassPhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        widget.trip.gatePassPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(10.5),
                                    bottomRight: Radius.circular(10.5),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: const Text(
                                  'Photo OK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : hasGatePass
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10.5),
                                    child: Image.memory(
                                      _gatePassPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 12),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10.5),
                                        bottomRight: Radius.circular(10.5),
                                      ),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: const Text(
                                      'Retake',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_rounded,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey.shade600,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                const AppText(
                                  'Gate Pass Photo',
                                  style: AppTextStyle.labelMedium,
                                  fontWeight: FontWeight.bold,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  'Click to take',
                                  style: AppTextStyle.labelMedium,
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.grey.shade400,
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isSubmitEnabled
              ? () async {
                  await controller.markTruckLoaded(
                    widget.trip.id,
                    _loadingPhotoBytes,
                    _gatePassPhotoBytes,
                  );
                  setState(() {
                    _loadingPhotoBytes = null;
                    _gatePassPhotoBytes = null;
                  });
                }
              : null,
          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
          label: Text(
            buttonLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            disabledBackgroundColor:
                isDark ? Colors.white10 : Colors.grey.shade200,
            disabledForegroundColor:
                isDark ? Colors.white24 : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationInfoCard(bool isDark) {
    final dropCity = widget.trip.dropCity;
    final dropLocation = widget.trip.dropLocation;
    if (dropCity.isEmpty && dropLocation.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF3B82F6),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppText(
                  'Destination / Delivery Address',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dropCity.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'City: ',
                  style: AppTextStyle.bodyMedium,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                Expanded(
                  child: AppText(
                    dropCity,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (dropLocation.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Location: ',
                  style: AppTextStyle.bodyMedium,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                Expanded(
                  child: AppText(
                    dropLocation,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTruckOwnerPassCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Truck Owner Pass (Issued by Admin)',
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.trip.truckOwnerPassId.isNotEmpty)
            AppText(
              'Pass ID: ${widget.trip.truckOwnerPassId}',
              style: AppTextStyle.bodyMedium,
              fontWeight: FontWeight.bold,
            ),
          if (widget.trip.truckOwnerPassData != null && widget.trip.truckOwnerPassData!['ownerName'] != null)
            AppText(
              'Owner/Transporter: ${widget.trip.truckOwnerPassData!['ownerName']}',
              style: AppTextStyle.bodyMedium,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
        ],
      ),
    );
  }

  Widget _buildAwaitingTruckOwnerPassCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF78350F) : const Color(0xFFFCD34D),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Admin is creating & uploading the Truck Owner Pass. Customer & destination details will unlock once pass is uploaded.',
              style: AppTextStyle.labelMedium,
              color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final bool isWaiting;
  final bool isDark;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;
  final VoidCallback? onAction;
  final Widget? customContent;

  const _StepTile({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    this.isWaiting = false,
    required this.isDark,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionColor,
    this.onAction,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? const Color(0xFF10B981)
                : isCurrent
                    ? actionColor
                    : isWaiting
                        ? const Color(0xFFF59E0B)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : isCurrent
                      ? actionColor
                      : isWaiting
                          ? const Color(0xFFF59E0B)
                          : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : isWaiting
                    ? const Icon(Icons.hourglass_empty_rounded,
                        color: Colors.white, size: 18)
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : (isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8)),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isLocked && !isWaiting
                      ? (isDark ? Colors.white30 : const Color(0xFF94A3B8))
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isWaiting
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
              ),
              if (customContent != null) ...[
                const SizedBox(height: 10),
                customContent!,
              ],
              if (isCurrent && onAction != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon, size: 16),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              if (isLocked &&
                  !isWaiting &&
                  !isCompleted &&
                  customContent == null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(actionIcon,
                        size: 14,
                        color: isDark ? Colors.white24 : Colors.grey.shade400),
                    label: Text(
                      actionLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                          color:
                              isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
              if (isWaiting) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFF59E0B).withOpacity(0.1)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Waiting for admin approval...',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
      ],
    );
  }
}
