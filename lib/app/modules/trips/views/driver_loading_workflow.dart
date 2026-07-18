import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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
        return 2;
      case 'LOAD_REQUESTED':
        return 3; // waiting for admin
      case 'ACTIVE NOW':
      case 'DELIVERY_REQUESTED':
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
              const AppText(
                'Loading Workflow',
                style: AppTextStyle.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
              const Spacer(),
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
            onAction: step == 0
                ? () => controller.startTrip(widget.trip.id)
                : null,
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
            subtitle: step > 2
                ? (step == 3
                    ? 'Photos submitted — waiting for admin approval'
                    : 'Admin ne loading approve kar di')
                : 'Loading & Gate Pass photo click karein',
            isCompleted: step > 3,
            isCurrent: step == 2,
            isLocked: step < 2,
            isWaiting: step == 3,
            isDark: isDark,
            actionLabel: 'Mark Loaded',
            actionIcon: Icons.camera_alt_rounded,
            actionColor: const Color(0xFFF59E0B),
            customContent: step == 2 ? _buildStep3Content(controller, isDark) : null,
          ),
          _buildConnector(isDark, step > 3),

          // Step 4: Start Delivery (Locked until approved)
          _StepTile(
            stepNumber: 4,
            title: 'Start Delivery',
            subtitle: step >= 4
                ? 'Destination unlocked — delivery shuru!'
                : 'Destination unlocks after approval',
            isCompleted: step >= 4 && widget.trip.status != 'ACTIVE NOW',
            isCurrent: step >= 4 && widget.trip.status == 'ACTIVE NOW',
            isLocked: step < 4,
            isDark: isDark,
            actionLabel: step >= 4 ? 'Start Delivery' : 'Locked',
            actionIcon: step >= 4
                ? Icons.delivery_dining_rounded
                : Icons.lock_rounded,
            actionColor: const Color(0xFF10B981),
            onAction: step >= 4 && widget.trip.status == 'ACTIVE NOW'
                ? () {
                    Get.snackbar(
                      'Delivery Started! 🚛',
                      'Destination: ${widget.trip.dropCity} — ${widget.trip.dropLocation}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981),
                      colorText: Colors.white,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isDark, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
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
    );
  }

  Widget _buildStep3Content(TripsController controller, bool isDark) {
    final hasLoading = _loadingPhotoBytes != null;
    final hasGatePass = _gatePassPhotoBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final bytes = await _capturePhotoFromCamera();
                  if (bytes != null) {
                    setState(() {
                      _loadingPhotoBytes = bytes;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: hasLoading ? const Color(0xFF10B981).withOpacity(0.08) : (isDark ? Colors.white10 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasLoading ? const Color(0xFF10B981).withOpacity(0.4) : (isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLoading ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                        color: hasLoading ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.grey.shade600),
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        hasLoading ? 'Loading Proof ✅' : 'Loading Photo 📷',
                        style: AppTextStyle.labelMedium,
                        fontWeight: FontWeight.bold,
                        color: hasLoading ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      if (hasLoading) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _loadingPhotoBytes = null;
                            });
                          },
                          child: const Text(
                            'Retake',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final bytes = await _capturePhotoFromCamera();
                  if (bytes != null) {
                    setState(() {
                      _gatePassPhotoBytes = bytes;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: hasGatePass ? const Color(0xFF10B981).withOpacity(0.08) : (isDark ? Colors.white10 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasGatePass ? const Color(0xFF10B981).withOpacity(0.4) : (isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasGatePass ? Icons.check_circle_rounded : Icons.assignment_rounded,
                        color: hasGatePass ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.grey.shade600),
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        hasGatePass ? 'Gate Pass ✅' : 'Gate Pass Photo 📷',
                        style: AppTextStyle.labelMedium,
                        fontWeight: FontWeight.bold,
                        color: hasGatePass ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      if (hasGatePass) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _gatePassPhotoBytes = null;
                            });
                          },
                          child: const Text(
                            'Retake',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: (hasLoading && hasGatePass)
              ? () async {
                  await controller.markTruckLoaded(
                    widget.trip.id,
                    _loadingPhotoBytes!,
                    _gatePassPhotoBytes!,
                  );
                  setState(() {
                    _loadingPhotoBytes = null;
                    _gatePassPhotoBytes = null;
                  });
                }
              : null,
          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
          label: const Text(
            'Submit Load & Gate Pass',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            disabledForegroundColor: isDark ? Colors.white24 : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
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
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
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
              ] else if (isCurrent && onAction != null) ...[
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
              if (isLocked && !isWaiting && !isCompleted && customContent == null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(actionIcon, size: 14,
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
                          color: isDark ? Colors.white12 : Colors.grey.shade300),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B)),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Waiting for admin approval...',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
