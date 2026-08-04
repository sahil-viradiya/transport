import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/location_permission_controller.dart';
import '../../../core/theme/app_colors.dart';

class LocationPermissionView extends GetView<LocationPermissionController> {
  const LocationPermissionView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              // Top Progress Indicator
              Row(
                children: [
                  _buildStepIndicator(1, active: true),
                  const SizedBox(width: 8),
                  _buildStepIndicator(2, active: true),
                  const SizedBox(width: 8),
                  _buildStepIndicator(3, active: false),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Step 2 of 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                ),
              ),

              const Spacer(),

              // Hero Map Pin Card
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Headline & Description
              Text(
                'Enable GPS Location 📍',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Location access allows real-time fleet tracking, automated waypoint check-ins, and accurate proof of delivery verifications.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey[300] : AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 36),

              // Feature Highlights List
              _buildFeatureTile(
                icon: Icons.alt_route_rounded,
                title: 'Live GPS Tracking & Navigation',
                subtitle: 'Provides turn-by-turn guidance and ETA updates to dispatchers.',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Automated Geofence Check-In',
                subtitle: 'Auto-logs arrival & departure at cargo hubs.',
                isDark: isDark,
              ),

              const Spacer(),

              // Action Buttons
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.requestLocationPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Enable Location Services',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: controller.skipPermission,
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, {required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 6,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
