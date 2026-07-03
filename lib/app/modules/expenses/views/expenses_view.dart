import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/expenses_controller.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../../data/services/session_service.dart';
import '../../../data/services/location_service.dart';

class ExpensesView extends GetView<ExpensesController> {
  const ExpensesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Obx(() {
        if (controller.isLoading.value && controller.expenses.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadExpenses,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header summary card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'TOTAL EXPENSES',
                        style: AppTextStyle.labelMedium,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      Obx(() => AppText(
                            controller.totalExpenses.value,
                            style: AppTextStyle.headlineLarge,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryStat('Approved', controller.approvedExpenses.value, Colors.greenAccent),
                          _buildSummaryStat('Pending', controller.pendingExpenses.value, Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expenses List title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AppText(
                    'RECENT EXPENSE CLAIMS',
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Claims list items
              Obx(() {
                if (controller.expenses.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint),
                            SizedBox(height: 8),
                            AppText('No expense claims recorded yet.', style: AppTextStyle.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = controller.expenses[index];
                      final title = item['title'] ?? 'Expense';
                      final desc = item['description'] ?? '';
                      final amt = item['amount'] ?? '₹0';
                      final date = item['date'] ?? '';
                      final status = item['status'] ?? 'Pending';
                      
                      Color iconCol = Colors.orange;
                      IconData iconData = Icons.local_gas_station_rounded;

                      if (title.contains('Toll')) {
                        iconCol = Colors.blue;
                        iconData = Icons.toll_rounded;
                      } else if (title.contains('Food')) {
                        iconCol = Colors.purple;
                        iconData = Icons.hotel_rounded;
                      } else if (title.contains('Repair') || title.contains('Tyre')) {
                        iconCol = Colors.red;
                        iconData = Icons.build_rounded;
                      } else if (title.contains('Other')) {
                        iconCol = Colors.grey;
                        iconData = Icons.receipt_rounded;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : iconCol.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: iconCol, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: AppText(title, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'Approved' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: AppText(
                                              status,
                                              style: AppTextStyle.labelMedium,
                                              color: status == 'Approved' ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      AppText(desc, style: AppTextStyle.bodyMedium),
                                      const SizedBox(height: 4),
                                      AppText('Trip: ${item['tripId'] ?? "N/A"} • $date', style: AppTextStyle.labelMedium),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppText(
                                  amt,
                                  style: AppTextStyle.bodyLarge,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: controller.expenses.length,
                  ),
                );
              }),

              // Bottom button space
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppButton(
                    text: 'File New Expense Claim',
                    icon: Icons.add_circle_outline_rounded,
                    onPressed: () => _showAddExpenseBottomSheet(context, isDark),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: AppTextStyle.labelMedium, color: Colors.white60),
        const SizedBox(height: 4),
        AppText(value, style: AppTextStyle.bodyLarge, color: color, fontWeight: FontWeight.bold),
      ],
    );
  }

  void _showAddExpenseBottomSheet(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: 'Fuel Top-up');
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    // Get active trip details
    String activeTripId = 'None';
    try {
      final tripsController = Get.find<TripsController>();
      final active = tripsController.allTrips.firstWhereOrNull((t) => t.isActive);
      if (active != null) {
        activeTripId = active.id;
      }
    } catch (_) {}
    
    final tripIdCtrl = TextEditingController(text: activeTripId);
    final receiptBytes = Rx<Uint8List?>(null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(bottomSheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const AppText(
                'File New Expense Claim',
                style: AppTextStyle.headlineSmall,
                fontWeight: FontWeight.bold,
              ),
              const Divider(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: titleCtrl.text,
                          decoration: const InputDecoration(
                            labelText: 'Expense Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Fuel Top-up', child: Text('Fuel Top-up')),
                            DropdownMenuItem(value: 'Toll Tax Payment', child: Text('Toll Tax Payment')),
                            DropdownMenuItem(value: 'Driver Food & Stay', child: Text('Driver Food & Stay')),
                            DropdownMenuItem(value: 'Tyre Repair Work', child: Text('Tyre Repair Work')),
                            DropdownMenuItem(value: 'Other Miscellaneous', child: Text('Other Miscellaneous')),
                          ],
                          onChanged: (val) {
                            if (val != null) titleCtrl.text = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: tripIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Trip ID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                          validator: (v) => v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description / Remarks',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description_rounded),
                          ),
                          maxLines: 2,
                          validator: (v) => v!.isEmpty ? 'Field required' : null,
                        ),
                        const SizedBox(height: 16),
                        // Receipt proof — required (photo of bill / receipt).
                        const AppText('RECEIPT PROOF',
                            style: AppTextStyle.labelMedium,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary),
                        const SizedBox(height: 6),
                        Obx(() => receiptBytes.value == null
                            ? OutlinedButton.icon(
                                onPressed: () async {
                                  final x = await ImagePicker().pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 70,
                                  );
                                  if (x != null) {
                                    receiptBytes.value = await x.readAsBytes();
                                  }
                                },
                                icon: const Icon(Icons.photo_camera_rounded),
                                label: const Text('Attach Receipt Photo'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              )
                            : Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(receiptBytes.value!,
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: AppText('Receipt attached ✓',
                                        style: AppTextStyle.bodyMedium,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextButton(
                                    onPressed: () => receiptBytes.value = null,
                                    child: const Text('Change'),
                                  ),
                                ],
                              )),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                              child: const AppText('Cancel', style: AppTextStyle.bodyMedium),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                if (receiptBytes.value == null) {
                                  AppSnackBar.showWarning(
                                      title: 'Proof Required',
                                      message:
                                          'Please attach a receipt photo as proof.');
                                  return;
                                }
                                final phone =
                                    Get.find<SessionService>().ownerKey;

                                double currentLat =
                                    LocationService.fallbackLatitude;
                                double currentLng =
                                    LocationService.fallbackLongitude;
                                String locationName = '';
                                try {
                                  final locationService =
                                      Get.find<LocationService>();
                                  final pos = await locationService
                                      .getCurrentPosition();
                                  currentLat = pos.latitude;
                                  currentLng = pos.longitude;
                                  locationName = await locationService
                                      .getAddressFromCoordinates(
                                          currentLat, currentLng);
                                } catch (_) {}

                                final expenseData = {
                                  'tripId': tripIdCtrl.text.trim(),
                                  'driverPhone': phone,
                                  'title': titleCtrl.text,
                                  'description': descCtrl.text.trim(),
                                  'amount': '₹${amountCtrl.text.trim()}',
                                  'date': 'Today',
                                  'latitude': currentLat,
                                  'longitude': currentLng,
                                  'locationName': locationName,
                                };
                                Navigator.of(bottomSheetCtx).pop();
                                await controller.submitExpense(expenseData,
                                    receiptBytes: receiptBytes.value);
                              },
                              child: const AppText('Submit Claim',
                                  style: AppTextStyle.bodyMedium, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
