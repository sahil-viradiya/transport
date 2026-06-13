import 'package:flutter/material.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';

class ExpensesView extends StatelessWidget {
  const ExpensesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dummyExpenses = [
      _ExpenseItem('Fuel Top-up', 'Trip #TRP-882910 • Indian Oil', '₹12,450', '24 Oct, 08:30 AM', Icons.local_gas_station_rounded, Colors.orange),
      _ExpenseItem('Toll Tax Payment', 'NH-48 Plaza • FastTag Auto-Debit', '₹850', '24 Oct, 11:20 AM', Icons.toll_rounded, Colors.blue),
      _ExpenseItem('Driver Food & Stay', 'Highway Dhaba • Food Allowance', '₹650', '23 Oct, 09:15 PM', Icons.hotel_rounded, Colors.purple),
      _ExpenseItem('Tyre Repair Work', 'Nagpur Bypass Workshop', '₹1,800', '22 Oct, 04:30 PM', Icons.build_rounded, Colors.red),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
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
                    'OCTOBER EXPENSES',
                    style: AppTextStyle.labelMedium,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    '₹15,750',
                    style: AppTextStyle.headlineLarge,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryStat('Approved', '₹13,950', Colors.greenAccent),
                      _buildSummaryStat('Pending', '₹1,800', Colors.orangeAccent),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = dummyExpenses[index];
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
                              color: isDark ? const Color(0xFF1E293B) : item.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon, color: item.color, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(item.title, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                                const SizedBox(height: 4),
                                AppText(item.description, style: AppTextStyle.bodyMedium),
                                const SizedBox(height: 2),
                                AppText(item.date, style: AppTextStyle.labelMedium),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(
                            item.amount,
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
              childCount: dummyExpenses.length,
            ),
          ),

          // Bottom button space
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton(
                text: 'File New Expense Claim',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
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
}

class _ExpenseItem {
  final String title;
  final String description;
  final String amount;
  final String date;
  final IconData icon;
  final Color color;

  _ExpenseItem(this.title, this.description, this.amount, this.date, this.icon, this.color);
}
