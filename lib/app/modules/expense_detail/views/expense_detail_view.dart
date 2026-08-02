import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/expense_detail_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/feedback_views.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';

class ExpenseDetailView extends GetView<ExpenseDetailController> {
  const ExpenseDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Expense Detail',
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppLoadingView();
        }

        final e = controller.expense.value;
        if (e == null) {
          return const AppEmptyView(title: 'Expense not found');
        }

        final title = (e['title'] ?? 'Expense').toString();
        final amount = (e['amount'] ?? '').toString();
        final tripId = (e['tripId'] ?? '').toString();
        final remarks = (e['remarks'] ?? '').toString();
        final status = controller.status;
        final receipt = (e['receiptUrl'] ?? '').toString();

        final statusColor = status == 'Approved'
            ? AppColors.success
            : (status == 'Rejected' ? AppColors.error : AppColors.tertiaryDark);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1B18) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF332E2A)
                                : AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_long_rounded,
                                color: statusColor, size: 36),
                          ),
                          const SizedBox(height: 12),
                          AppText(title,
                              style: AppTextStyle.titleLarge,
                              fontWeight: FontWeight.bold,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          AppText(amount,
                              style: AppTextStyle.headlineMedium,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AppText(status,
                                style: AppTextStyle.bodyMedium,
                                color: statusColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detail Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1B18) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF332E2A)
                                : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText('EXPENSE INFORMATION',
                              style: AppTextStyle.labelMedium,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary),
                          const Divider(height: 24),
                          if (tripId.isNotEmpty) ...[
                            _buildInfoRow('Associated Trip', tripId, isDark),
                            const Divider(height: 20),
                          ],
                          if (remarks.isNotEmpty) ...[
                            _buildInfoRow(
                                'Remarks / Description', remarks, isDark),
                            const Divider(height: 20),
                          ],
                          _buildInfoRow(
                              'Expense ID', controller.expenseId, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Receipt Card
                    if (receipt.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1F1B18) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF332E2A)
                                  : AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText('RECEIPT PROOF',
                                style: AppTextStyle.labelMedium,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Container(
                              height: 240,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF332E2A)
                                        : AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                corsSafeImageUrl(receipt),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      color: AppColors.textHint, size: 36),
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
            ),

            // Action Buttons for Admin (Approve / Reject)
            if (controller.canAct)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181512) : Colors.white,
                  border: Border(
                    top: BorderSide(
                        color: isDark
                            ? const Color(0xFF332E2A)
                            : AppColors.border),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Reject',
                          type: AppButtonType.secondary,
                          onPressed: controller.promptReject,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Approve',
                          type: AppButtonType.primary,
                          onPressed: controller.approve,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label.toUpperCase(),
            style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        AppText(value,
            style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
      ],
    );
  }
}
