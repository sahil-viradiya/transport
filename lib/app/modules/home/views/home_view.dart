import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../trips/views/trips_view.dart';
import '../../expenses/views/expenses_view.dart';
import '../../inspection/views/inspection_view.dart';
import '../../profile/views/profile_view.dart';
import '../../../core/theme/app_colors.dart';

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
      const InspectionView(),
      const ProfileView(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        controller.handleBackPress();
      },
      child: Scaffold(
        body: Obx(() => IndexedStack(
              index: controller.currentIndex.value,
              children: pages,
            )),
        bottomNavigationBar: Obx(() => NavigationBar(
              selectedIndex: controller.currentIndex.value,
              onDestinationSelected: controller.changeTabIndex,
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              indicatorColor: AppColors.primaryLight,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary),
                  label: 'home'.tr,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.local_shipping_outlined),
                  selectedIcon: const Icon(Icons.local_shipping_rounded, color: AppColors.primary),
                  label: 'trips'.tr,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  label: 'expenses'.tr,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.fact_check_outlined),
                  selectedIcon:
                      const Icon(Icons.fact_check_rounded, color: AppColors.primary),
                  label: 'inspection'.tr,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                  label: 'profile'.tr,
                ),
              ],
            )),
      ),
    );
  }
}
