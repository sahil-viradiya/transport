import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/theme/app_colors.dart';

/// Redesigned Inspection screen matching the reference design:
/// - Compact top app bar with back navigation and clean "Inspection" title
/// - Two compact pill-style tabs (Pending | History)
/// - Clean white inspection card with truck details, status badge, 2-column info, and message
/// - Full-width green "START INSPECTION" button
/// - Supports all dynamic states (no truck, pending assignment, ready, pending review, issues)
class InspectionView extends StatefulWidget {
  const InspectionView({super.key});

  @override
  State<InspectionView> createState() => _InspectionViewState();
}

class _InspectionViewState extends State<InspectionView> {
  final RxInt _selectedTab = 0.obs; // 0: Pending, 1: History

  DashboardController get controller => Get.find<DashboardController>();

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().changeTabIndex(0);
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
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Inspection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _buildTabSelector(isDark),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (_selectedTab.value == 1) {
                  return _buildHistoryTab(context, isDark);
                }
                return _buildPendingTab(context, isDark);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pill-style Tabs: Pending | History ──────────────────────────────────────
  Widget _buildTabSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Obx(() {
          final isPending = _selectedTab.value == 0;
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectedTab.value = 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFF16A34A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isPending
                          ? [
                              BoxShadow(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isPending ? FontWeight.w700 : FontWeight.w600,
                        color: isPending
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectedTab.value = 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isPending
                          ? const Color(0xFF16A34A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: !isPending
                          ? [
                              BoxShadow(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            !isPending ? FontWeight.w700 : FontWeight.w600,
                        color: !isPending
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Pending Tab Content ─────────────────────────────────────────────────────
  Widget _buildPendingTab(BuildContext context, bool isDark) {
    return Obx(() {
      final truck = controller.myTruck.value;
      if (truck == null) {
        return _buildNoTruckEmptyState(isDark);
      }

      final inspection = controller.truckInspection;
      final truckNo = (truck['truckNo'] ?? '').toString();
      final issue = (truck['inspectionIssue'] ?? '').toString();

      // Case: Driver needs to review & accept/reject new truck assignment
      if (inspection == 'pending_confirmation') {
        return _buildPendingConfirmationReview(context, isDark, truck, truckNo);
      }

      final (chipLabel, chipBg, chipFg) = switch (inspection) {
        'ready' => ('Ready', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
        'inspected_pending_review' => (
            'Pending Review',
            const Color(0xFFFEF3C7),
            const Color(0xFFB45309)
          ),
        'approved_pending_accept' => (
            'Approved',
            const Color(0xFFDCFCE7),
            const Color(0xFF15803D)
          ),
        'problem' => (
            'Issue Reported',
            const Color(0xFFFEE2E2),
            const Color(0xFFDC2626)
          ),
        _ => ('Pending', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      };

      String statusText = 'Please inspect your truck and submit.';
      if (inspection == 'ready') {
        statusText = 'Aapka truck inspection approved hai — trip ke liye ready.';
      } else if (inspection == 'inspected_pending_review') {
        statusText =
            'Inspection report admin ko review ke liye bhej di gayi hai.';
      } else if (inspection == 'approved_pending_accept') {
        statusText =
            'Admin ne inspection approve kar di hai. Kripya truck accept karein.';
      } else if (inspection == 'problem' && issue.isNotEmpty) {
        statusText = 'Truck me problem reported hai: $issue';
      }

      final submittedOn = (truck['inspectedAt'] ??
              truck['assignedDate'] ??
              truck['date'] ??
              'Today')
          .toString();

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                  // Top row: Truck Icon + Truck Number + Status Pill
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Truck: $truckNo',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chipLabel,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      height: 1,
                      thickness: 1,
                    ),
                  ),

                  // 2-Column Information Layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _infoColumn(
                          'Submitted On',
                          submittedOn,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoColumn(
                          'Status',
                          chipLabel,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _infoColumn(
                          'Model',
                          (truck['model'] ?? 'Tata Signa').toString(),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoColumn(
                          'Type',
                          (truck['type'] ?? '12 Wheel').toString(),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Inspection Instruction / Message Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Button
                  if (inspection == 'approved_pending_accept')
                    ElevatedButton.icon(
                      onPressed: controller.acceptMyTruck,
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 18, color: Colors.white),
                      label: const Text(
                        'Accept Truck',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    )
                  else if (inspection == 'pending' ||
                      inspection == 'problem' ||
                      inspection.isEmpty)
                    ElevatedButton.icon(
                      onPressed: () =>
                          Get.to(() => const TruckInspectionFormView()),
                      icon: const Icon(Icons.fact_check_rounded,
                          size: 18, color: Colors.white),
                      label: const Text(
                        'START INSPECTION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    )
                  else if (inspection == 'inspected_pending_review')
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              size: 16, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Text(
                            'Under Admin Review',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
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
    });
  }

  // ── History Tab Content ─────────────────────────────────────────────────────
  Widget _buildHistoryTab(BuildContext context, bool isDark) {
    return Obx(() {
      final truck = controller.myTruck.value;
      if (truck == null) {
        return _buildNoTruckEmptyState(isDark);
      }

      final inspection = controller.truckInspection;
      final truckNo = (truck['truckNo'] ?? '').toString();
      final hasHistory = inspection == 'ready' ||
          inspection == 'inspected_pending_review' ||
          inspection == 'approved_pending_accept';

      if (!hasHistory) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: isDark ? Colors.white38 : AppColors.textHint,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Inspection History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed inspections will appear here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final submittedOn = (truck['inspectedAt'] ??
              truck['assignedDate'] ??
              truck['date'] ??
              'Today')
          .toString();

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Truck: $truckNo',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Approved',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _infoColumn('Inspected Date', submittedOn, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoColumn(
                      'Inspector',
                      controller.driverName.value.isNotEmpty
                          ? controller.driverName.value
                          : 'Driver',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _infoColumn(
                      'Model',
                      (truck['model'] ?? 'Tata Signa').toString(),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoColumn(
                      'Status',
                      'Checklist Passed ✅',
                      isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _infoColumn(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            letterSpacing: 0.2,
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

  Widget _buildNoTruckEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.no_transfer_rounded,
                size: 32,
                color: isDark ? Colors.white38 : AppColors.textHint,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Koi truck assigned nahi hai.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Admin truck assign karega tab inspection hoga.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending Confirmation Review ─────────────────────────────────────────────
  Widget _buildPendingConfirmationReview(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> truck,
    String truckNo,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Truck Assignment Review',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin has assigned a truck. Review and confirm.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const Divider(height: 24),
                _buildReviewRow('Driver', controller.driverName.value, isDark),
                const Divider(height: 20),
                _buildReviewRow('Truck No', truckNo, isDark),
                const Divider(height: 20),
                _buildReviewRow(
                    'Truck Name',
                    (truck['model'] ?? 'Tata Signa').toString(),
                    isDark),
                const Divider(height: 20),
                _buildReviewRow(
                    'Truck Type',
                    (truck['type'] ?? '12 Wheel').toString(),
                    isDark),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(
                        color: Color(0xFFFCA5A5), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _showRejectAssignmentDialog(context, truckNo),
                  child: const Text('Reject',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => controller.confirmTruckAssignment(true),
                  child: const Text('Accept',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showRejectAssignmentDialog(BuildContext context, String truckNo) {
    final reasonCtrl = TextEditingController();
    Uint8List? selectedImageBytes;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Reject Assignment',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kripya reject karne ka kaaran (reason) aur photo attach karein.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Reason for rejection',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          selectedImageBytes!,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(
                            source: ImageSource.camera, imageQuality: 70);
                        if (x != null) {
                          final bytes = await x.readAsBytes();
                          setState(() => selectedImageBytes = bytes);
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                      label: const Text('Attach Photo',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
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
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) {
                    Get.snackbar('Reason Required',
                        'Kripya reject karne ka reason likhein.');
                    return;
                  }
                  if (selectedImageBytes == null) {
                    Get.snackbar('Photo Required',
                        'Kripya reject karne ke liye photo attach karein.');
                    return;
                  }
                  Get.back();
                  AppPopup.showLoading(message: 'Submitting report...');
                  try {
                    final firebaseService = Get.find<FirebaseService>();
                    final imageUrl = await firebaseService
                        .uploadTruckIssueImage(truckNo, selectedImageBytes);

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
        },
      ),
    );
  }
}

/// Checklist form: Good / Issue Found per item, remarks, photos.
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
      Get.snackbar(
        'Photo Required',
        'Issue report ke liye kam se kam 1 photo attach karein.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
      );
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
          'Truck Inspection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            color: const Color(0xFF16A34A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Responsive Condition Fields Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 550;
                  if (isWide) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: items
                          .map((item) => SizedBox(
                                width: itemWidth,
                                child: _checkTile(isDark, item),
                              ))
                          .toList(),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children:
                        items.map((item) => _checkTile(isDark, item)).toList(),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Other Issues / Remarks Section
              Text(
                'Other Issues / Remarks (Optional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe any issue...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Image Upload Section
              Text(
                'Upload Images (Min 1 for issues)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...images.asMap().entries.map((e) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.memory(
                                  e.value,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: -4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => images.removeAt(e.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )),
                    GestureDetector(
                      onTap: _addImage,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_a_photo_rounded,
                              color: Color(0xFF16A34A),
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+ Add',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Submit Inspection Button
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'SUBMIT INSPECTION',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkTile(bool isDark, String item) {
    final good = results[item]!;

    Widget option(String label, bool value) {
      final selected = good == value;
      final color = value ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      final bg = value
          ? const Color(0xFFDCFCE7).withValues(alpha: 0.5)
          : const Color(0xFFFEE2E2).withValues(alpha: 0.5);

      return Expanded(
        child: InkWell(
          onTap: () => setState(() => results[item] = value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? bg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? color
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 16,
                  color: selected
                      ? color
                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected
                          ? (isDark && value
                              ? const Color(0xFF86EFAC)
                              : color)
                          : (isDark
                              ? Colors.white70
                              : const Color(0xFF64748B)),
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              option('Good', true),
              const SizedBox(width: 8),
              option('Issue Found', false),
            ],
          ),
        ],
      ),
    );
  }
}

/// Success screen after submitting the inspection.
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
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFF16A34A), width: 2.5),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF16A34A), size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Inspection Submitted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your inspection has been sent to admin for review.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
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
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

