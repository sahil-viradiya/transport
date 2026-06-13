import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../trips/views/trips_view.dart';
import '../../expenses/views/expenses_view.dart';
import '../../profile/views/profile_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../widgets/app_text.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> pages = [
      const DashboardView(),
      const TripsView(),
      const ExpensesView(),
      const ProfileView(),
    ];

    return Scaffold(
      body: Obx(() => IndexedStack(
            index: controller.currentIndex.value,
            children: pages,
          )),
      bottomNavigationBar: Obx(() => BottomNavigationBar(
            currentIndex: controller.currentIndex.value,
            onTap: controller.changeTabIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDark ? Colors.white30 : Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            elevation: 8,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping_outlined),
                activeIcon: Icon(Icons.local_shipping_rounded),
                label: 'Trips',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Expenses',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          )),
    );
  }
}
