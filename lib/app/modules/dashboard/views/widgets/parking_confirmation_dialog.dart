import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../../widgets/app_text.dart';
import '../../../../../widgets/app_button.dart';
import '../../../../../widgets/dialogs/app_snackbar.dart';

class ParkingConfirmationDialog extends StatefulWidget {
  final String driverName;
  final String driverId;
  final String vehicleNo;
  final String address;
  final double distanceKm;
  final Function(Uint8List photoBytes) onSubmit;

  const ParkingConfirmationDialog({
    super.key,
    required this.driverName,
    required this.driverId,
    required this.vehicleNo,
    required this.address,
    required this.distanceKm,
    required this.onSubmit,
  });

  static Future<void> show({
    BuildContext? context,
    required String driverName,
    required String driverId,
    required String vehicleNo,
    required String address,
    required double distanceKm,
    required Function(Uint8List photoBytes) onSubmit,
  }) async {
    await Get.bottomSheet(
      ParkingConfirmationDialog(
        driverName: driverName,
        driverId: driverId,
        vehicleNo: vehicleNo,
        address: address,
        distanceKm: distanceKm,
        onSubmit: onSubmit,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<ParkingConfirmationDialog> createState() =>
      _ParkingConfirmationDialogState();
}

class _ParkingConfirmationDialogState
    extends State<ParkingConfirmationDialog> {
  Uint8List? _selectedPhotoBytes;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedPhotoBytes = bytes;
        });
      }
    } catch (e) {
      AppSnackBar.showError(
        title: 'Camera/Gallery Error',
        message: 'Could not capture image. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nowStr = DateTime.now().toString().split('.')[0];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.local_parking_rounded,
                    color: AppColors.primary, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    'Parking Confirmation Request',
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const AppText(
              'Submit location and truck photo to request station verification.',
              style: AppTextStyle.bodyMedium,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),

            // Captured Metadata Summary Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDark ? Colors.white10 : AppColors.primaryLight),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.person_rounded, 'Driver',
                      '${widget.driverName} (${widget.driverId})'),
                  const Divider(height: 14),
                  _infoRow(Icons.local_shipping_rounded, 'Truck ID',
                      widget.vehicleNo),
                  const Divider(height: 14),
                  _infoRow(
                      Icons.access_time_rounded, 'Arrival Time', nowStr),
                  const Divider(height: 14),
                  _infoRow(Icons.location_on_rounded, 'Live Location',
                      widget.address),
                  const Divider(height: 14),
                  _infoRow(
                    Icons.straighten_rounded,
                    'Station Distance',
                    '${widget.distanceKm.toStringAsFixed(2)} km away',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mandatory Truck Photo Section
            Row(
              children: [
                const AppText(
                  'Truck Photo',
                  style: AppTextStyle.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const AppText(
                    'Mandatory *',
                    style: AppTextStyle.labelMedium,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_selectedPhotoBytes != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _selectedPhotoBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPhotoBytes = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Take Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            AppButton(
              text: _isUploading
                  ? 'Submitting Request...'
                  : 'Submit Parking Confirmation',
              icon: Icons.send_rounded,
              onPressed: _isUploading
                  ? null
                  : () async {
                      if (_selectedPhotoBytes == null) {
                        AppSnackBar.showWarning(
                          title: 'Photo Required 📷',
                          message:
                              'Truck Photo is mandatory for parking confirmation.',
                        );
                        return;
                      }
                      setState(() => _isUploading = true);
                      try {
                        await widget.onSubmit(_selectedPhotoBytes!);
                        if (mounted) Get.back();
                      } finally {
                        if (mounted) setState(() => _isUploading = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: AppText(
            title,
            style: AppTextStyle.labelMedium,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: AppText(
            value,
            style: AppTextStyle.bodyMedium,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
