import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../core/theme/app_colors.dart';

/// Reference "Inspection" tab: the assigned truck's pending inspection with
/// Start Inspection → checklist form → submitted screen. Submitting drives the
/// SAME functionality as before (acceptTruck / reportTruckIssue).
class InspectionView extends GetView<DashboardController> {
  const InspectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Inspection',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        final truck = controller.myTruck.value;
        if (truck == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_transfer_rounded,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  AppText('Koi truck assigned nahi hai.',
                      style: AppTextStyle.bodyLarge),
                  AppText('Admin truck assign karega tab inspection hoga.',
                      style: AppTextStyle.labelMedium),
                ],
              ),
            ),
          );
        }

        final inspection = controller.truckInspection;
        final truckNo = (truck['truckNo'] ?? '').toString();
        final issue = (truck['inspectionIssue'] ?? '').toString();

        if (inspection == 'pending_confirmation') {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const AppText(
                  'Truck Assignment',
                  style: AppTextStyle.headlineMedium,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const AppText(
                  'Driver review screen',
                  style: AppTextStyle.bodyMedium,
                  color: Colors.grey,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewRow('Driver', controller.driverName.value),
                      const Divider(height: 24),
                      _buildReviewRow('Truck No', truckNo),
                      const Divider(height: 24),
                      _buildReviewRow('Truck Name', (truck['model'] ?? 'Tata Signa').toString()),
                      const Divider(height: 24),
                      _buildReviewRow('Truck Type', (truck['type'] ?? '12 Wheel').toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showRejectAssignmentDialog(context, truckNo),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => controller.confirmTruckAssignment(true),
                        child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final (chipLabel, chipColor) = switch (inspection) {
          'ready' => ('Ready', AppColors.success),
          'inspected_pending_review' => ('Pending Review', AppColors.tertiary),
          'approved_pending_accept' => ('Approved', AppColors.success),
          'problem' => ('Issue Reported', AppColors.error),
          _ => ('Pending', AppColors.textSecondary),
        };

        String statusText = 'Please inspect your truck and submit.';
        if (inspection == 'ready') {
          statusText = 'Aapka truck inspection approved hai — trip ke liye ready.';
        } else if (inspection == 'inspected_pending_review') {
          statusText = 'Inspection report admin ko review ke liye bhej di gayi hai.';
        } else if (inspection == 'approved_pending_accept') {
          statusText = 'Admin ne inspection approve kar di hai. Kripya truck accept karein.';
        } else if (inspection == 'problem' && issue.isNotEmpty) {
          statusText = 'Truck me problem reported hai: $issue';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? Colors.white10 : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppText('Truck: $truckNo',
                              style: AppTextStyle.bodyLarge,
                              fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: chipColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AppText(chipLabel,
                              style: AppTextStyle.labelMedium,
                              color: chipColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      statusText,
                      style: AppTextStyle.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    if (inspection == 'approved_pending_accept')
                      ElevatedButton(
                        onPressed: controller.acceptMyTruck,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept Truck', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    else if (inspection == 'pending' || inspection == 'problem' || inspection.isEmpty)
                      ElevatedButton(
                        onPressed: () =>
                            Get.to(() => const TruckInspectionFormView()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Start Inspection'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(label, style: AppTextStyle.bodyMedium, color: Colors.grey),
        AppText(value, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
      ],
    );
  }

  void _showRejectAssignmentDialog(BuildContext context, String truckNo) {
    final reasonCtrl = TextEditingController();
    Uint8List? selectedImageBytes;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.report_problem_rounded, color: AppColors.error),
                SizedBox(width: 8),
                AppText('Reject Truck Assignment', style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText(
                      'Kripya reject karne ka kaaran (reason) aur photo attach karein.',
                      style: AppTextStyle.labelMedium,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Reason for rejection',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          selectedImageBytes!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
                        if (x != null) {
                          final bytes = await x.readAsBytes();
                          setState(() => selectedImageBytes = bytes);
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: const Text('Capture / Attach Photo'),
                    ),
                  ],
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
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) {
                    Get.snackbar('Reason Required', 'Kripya reject karne ka reason likhein.');
                    return;
                  }
                  if (selectedImageBytes == null) {
                    Get.snackbar('Photo Required', 'Kripya reject karne ke liye photo attach karein.');
                    return;
                  }
                  Get.back();
                  AppPopup.showLoading(message: 'Submitting reject report...');
                  try {
                    final firebaseService = Get.find<FirebaseService>();
                    final imageUrl = await firebaseService.uploadTruckIssueImage(truckNo, selectedImageBytes);

                    await controller.confirmTruckAssignment(
                      false,
                      rejectReason: reason,
                      rejectImageUrl: imageUrl,
                    );
                  } catch (e) {
                    AppPopup.hideLoading();
                    Get.snackbar('Error', e.toString());
                  }
                },
                child: const Text('Submit Reject'),
              ),
            ],
          );
        }
      ),
    );
  }
}

/// Reference checklist form: Good / Issue Found per item, remarks, photos.
class TruckInspectionFormView extends StatefulWidget {
  const TruckInspectionFormView({super.key});

  @override
  State<TruckInspectionFormView> createState() =>
      _TruckInspectionFormViewState();
}

class _TruckInspectionFormViewState extends State<TruckInspectionFormView> {
  static const items = [
    'Engine Condition',
    'Tyre Condition',
    'Brake System',
    'Lights & Indicators',
    'Body / Exterior',
  ];

  final Map<String, bool> results = {for (final i in items) i: true};
  final remarksCtrl = TextEditingController();
  final List<Uint8List> images = [];

  @override
  void dispose() {
    remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => images.add(bytes));
    }
  }

  Future<void> _submit() async {
    final hasIssue = results.values.any((good) => !good);
    if (hasIssue && images.isEmpty) {
      Get.snackbar('Photo Required',
          'Issue report ke liye kam se kam 1 photo attach karein.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final ok = await Get.find<DashboardController>().submitInspection(
      results: results,
      remarks: remarksCtrl.text,
      images: images,
    );
    if (ok && mounted) {
      Get.off(() => const InspectionSubmittedView());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Truck Inspection',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...items.map((item) => _checkTile(isDark, item)),
            const SizedBox(height: 8),
            const AppText('Other Issues / Remarks (Optional)',
                style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 6),
            TextField(
              controller: remarksCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Describe any issue...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const AppText('Upload Images (Min 1 for issues)',
                style: AppTextStyle.labelMedium, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...images.asMap().entries.map((e) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(e.value,
                                  width: 72, height: 72, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: -6,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => images.removeAt(e.key)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  GestureDetector(
                    onTap: _addImage,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Submit Inspection'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _checkTile(bool isDark, String item) {
    final good = results[item]!;
    Widget option(String label, bool value) {
      final selected = good == value;
      final color = value ? AppColors.success : AppColors.error;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => results[item] = value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 16,
                    color: selected ? color : AppColors.textHint),
                const SizedBox(width: 6),
                AppText(label,
                    style: AppTextStyle.labelMedium,
                    color: selected ? color : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(item,
              style: AppTextStyle.bodyMedium, fontWeight: FontWeight.w700),
          const SizedBox(height: 8),
          Row(
            children: [
              option('Good', true),
              const SizedBox(width: 10),
              option('Issue Found', false),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reference success screen after submitting the inspection.
class InspectionSubmittedView extends StatelessWidget {
  const InspectionSubmittedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.primary, size: 56),
              ),
              const SizedBox(height: 24),
              const AppText('Inspection Submitted!',
                  style: AppTextStyle.headlineMedium,
                  fontWeight: FontWeight.w800),
              const SizedBox(height: 8),
              const AppText(
                'Your inspection has been sent to admin for review.',
                style: AppTextStyle.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    try {
                      Get.find<HomeController>().changeTabIndex(0);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Go to Dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
