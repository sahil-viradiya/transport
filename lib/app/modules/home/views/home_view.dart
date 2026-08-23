import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../trips/views/trips_view.dart';
import '../../inspection/views/inspection_view.dart';
import '../../profile/views/profile_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> pages = [
      const DashboardView(),
      const TripsView(),
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
        bottomNavigationBar: Obx(() => Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                height: 64,
                elevation: 0,
                selectedIndex: controller.currentIndex.value,
                onDestinationSelected: controller.changeTabIndex,
                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                indicatorColor: const Color(0xFFDCFCE7),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined, size: 22),
                    selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF16A34A), size: 22),
                    label: 'home'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.local_shipping_outlined, size: 22),
                    selectedIcon: const Icon(Icons.local_shipping_rounded, color: Color(0xFF16A34A), size: 22),
                    label: 'trips'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.fact_check_outlined, size: 22),
                    selectedIcon:
                        const Icon(Icons.fact_check_rounded, color: Color(0xFF16A34A), size: 22),
                    label: 'inspection'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded, size: 22),
                    selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF16A34A), size: 22),
                    label: 'profile'.tr,
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
