import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      } else {
        return const NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pull driver controller details if active
    final driverController = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const AppText('The Highway Authority', style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sliding Segmented Selector
          _buildSegmentedControl(isDark),
          
          // 2. Tab Content Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.loadProfileFromFirebase,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Obx(() {
                  if (controller.activeSubTab.value == 0) {
                    return _buildProfileDetailsTab(driverController, isDark);
                  } else {
                    return _buildDocumentsTab(isDark);
                  }
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Segmented Switcher Pill
  Widget _buildSegmentedControl(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Obx(() {
        final selected = controller.activeSubTab.value;
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectSubTab(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected == 0
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: selected == 0
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AppText(
                      'Profile Info',
                      style: AppTextStyle.bodyMedium,
                      fontWeight: selected == 0 ? FontWeight.bold : FontWeight.normal,
                      color: selected == 0
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectSubTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected == 1
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: selected == 1
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AppText(
                      'My Documents',
                      style: AppTextStyle.bodyMedium,
                      fontWeight: selected == 1 ? FontWeight.bold : FontWeight.normal,
                      color: selected == 1
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // TAB 1: Profile Details
  Widget _buildProfileDetailsTab(DashboardController driverController, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Profile Banner Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF42526E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Stack(
            children: [
              // Road landscape overlay simulation
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1506015391300-4802dc74de2e?w=400&auto=format&fit=crop',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black26,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  onPressed: controller.showEditProfileDialog,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Obx(() => CircleAvatar(
                              radius: 46,
                              backgroundImage: _getImageProvider(driverController.avatarUrl.value),
                              backgroundColor: Colors.grey.shade200,
                            )),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: controller.changeAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(() => AppText(
                      driverController.driverName.value,
                      style: AppTextStyle.headlineMedium,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 4),
                    Obx(() => AppText(
                      'ID: ${driverController.vehicleNo.value}',
                      style: AppTextStyle.bodyMedium,
                      color: Colors.white70,
                    )),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0B3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFFBF2600), size: 16),
                          SizedBox(width: 6),
                          AppText(
                            'ACTIVE DUTY',
                            style: AppTextStyle.labelMedium,
                            color: Color(0xFFBF2600),
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),

        // 2. License Details Card
        _buildSectionCard(
          isDark: isDark,
          title: 'License Details',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDetailItem('LICENSE NUMBER', controller.licenseNo.value, isDark),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem('CLASS', controller.licenseClass.value, isDark),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppText('EXPIRES', style: AppTextStyle.labelMedium, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      const SizedBox(height: 4),
                      AppText(controller.licenseExpires.value, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold, color: AppColors.error),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. Driver & Vehicle Details Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Driver & Vehicle Details',
          icon: Icons.local_shipping_outlined,
          actionText: 'EDIT',
          onActionTap: controller.showEditProfileDialog,
          child: Column(
            children: [
              Obx(() => _buildHorizontalRow('Driver Phone', driverController.driverPhone.value, isDark)),
              const Divider(height: 16),
              Obx(() => _buildHorizontalRow('Vehicle No', driverController.vehicleNo.value, isDark)),
              const Divider(height: 16),
              Obx(() => _buildHorizontalRow('Vehicle Model', driverController.vehicleModel.value, isDark)),
            ],
          ),
        ),

        _buildSectionCard(
          isDark: isDark,
          title: 'Road Performance',
          icon: Icons.assessment_outlined,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      controller.safetyRating.value, 
                      style: AppTextStyle.headlineMedium, 
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold
                    ),
                    const AppText('Safety Rating', style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                  ],
                ),
              ),
              Container(height: 30, width: 1, color: isDark ? Colors.white24 : AppColors.border),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      controller.kmDriven.value, 
                      style: AppTextStyle.headlineMedium, 
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold
                    ),
                    const AppText('KM Driven', style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 4. Emergency Contact Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Emergency Contact',
          icon: Icons.contact_emergency_outlined,
          actionText: 'EDIT',
          onActionTap: controller.showEditEmergencyContactDialog,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: const AppText('SK', style: AppTextStyle.bodyMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => AppText(
                        controller.emergencyContactName.value,
                        style: AppTextStyle.bodyMedium,
                        fontWeight: FontWeight.bold
                      )),
                      Obx(() => AppText(
                        '${controller.emergencyRelation.value} • ${controller.emergencyPhone.value}',
                        style: AppTextStyle.labelMedium,
                        color: AppColors.textSecondary
                      )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: const CircleBorder(),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),

        // 5. Company Information Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Company Information',
          icon: Icons.business_outlined,
          child: Column(
            children: [
              _buildHorizontalRow('Employer', controller.employer.value, isDark),
              const Divider(height: 20),
              _buildHorizontalRow('Fleet Hub', controller.fleetHub.value, isDark),
              const Divider(height: 20),
              _buildHorizontalRow('App Version', controller.appVersion.value, isDark),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 6. Logout Action Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const AppText('Logout', style: AppTextStyle.bodyLarge, color: AppColors.error, fontWeight: FontWeight.bold),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: driverController.logout,
          ),
        ),

        const SizedBox(height: 24),
        
        // Footer Powered text
        const Center(
          child: AppText(
            'POWERED BY\nMinistry of Road Transport & Highways',
            textAlign: TextAlign.center,
            style: AppTextStyle.labelMedium,
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // TAB 2: Documents list (Left Screen)
  Widget _buildDocumentsTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const AppText(
            'My Documents',
            style: AppTextStyle.headlineMedium,
            fontWeight: FontWeight.w900,
          ),
          const SizedBox(height: 4),
          AppText(
            'Manage your digital credentials and expiry alerts.',
            style: AppTextStyle.bodyMedium,
            color: isDark ? Colors.white54 : AppColors.textSecondary,
          ),
          const SizedBox(height: 24),

          // Reactive document card list
          Obx(() {
            return Column(
              children: controller.documents.map((doc) => _buildDocumentCard(doc, isDark)).toList(),
            );
          }),

          const SizedBox(height: 8),

          // Blue CTA Box: Need to add new docs?
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              children: [
                // Abstract vector folder icon overlay
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Opacity(
                    opacity: 0.15,
                    child: Icon(Icons.folder_copy_rounded, size: 80, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Need to add new docs?',
                      style: AppTextStyle.headlineSmall,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 8),
                    const AppText(
                      'Upload high-resolution scans of your RC and Permit for faster verification.',
                      style: AppTextStyle.bodyMedium,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: controller.showAddNewDocumentDialog,
                      child: const AppText(
                        'Add New Document',
                        style: AppTextStyle.bodyMedium,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Single document item card builder
  Widget _buildDocumentCard(DriverDocumentModel doc, bool isDark) {
    Color statusBgColor = Colors.grey;
    Color statusTextColor = Colors.white;
    if (doc.status == 'Valid') {
      statusBgColor = AppColors.primaryLight;
      statusTextColor = AppColors.primary;
    } else if (doc.status == 'Expired') {
      statusBgColor = const Color(0xFFFFE380).withValues(alpha: 0.4);
      statusTextColor = const Color(0xFFBF2600);
    } else if (doc.status == 'Active') {
      statusBgColor = const Color(0xFFFFF0B3);
      statusTextColor = const Color(0xFFBF2600);
    }

    // Adapt layout names & badges to match reference precisely
    final displayStatus = doc.status == 'Expired' ? 'Expired' : doc.status;
    final displayStatusBg = doc.status == 'Expired' ? const Color(0xFFFFEBE6) : statusBgColor;
    final displayStatusText = doc.status == 'Expired' ? AppColors.error : statusTextColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Icon, Titles & Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: doc.status == 'Expired' 
                      ? const Color(0xFFFFEBE6) 
                      : (isDark ? const Color(0xFF0F172A) : AppColors.primaryLight),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  doc.icon, 
                  color: doc.status == 'Expired' ? AppColors.error : AppColors.primary, 
                  size: 24
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(doc.title, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold),
                    AppText(doc.subtitle, style: AppTextStyle.labelMedium, color: AppColors.textSecondary),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: displayStatusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppText(
                  displayStatus, 
                  style: AppTextStyle.labelMedium, 
                  color: displayStatusText, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Expiry Info Middle Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: doc.status == 'Expired' 
                  ? const Color(0xFFFFEBE6).withValues(alpha: 0.3) 
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7FD)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('EXPIRY DATE', style: AppTextStyle.labelMedium, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    const SizedBox(height: 4),
                    AppText(
                      doc.expiryDate, 
                      style: AppTextStyle.bodyMedium, 
                      fontWeight: FontWeight.bold,
                      color: doc.status == 'Expired' ? AppColors.error : AppColors.textPrimary
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (doc.status == 'Expired') ...[
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const AppText('STATUS', style: AppTextStyle.labelMedium, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        const SizedBox(height: 4),
                        AppText(
                          doc.statusMsg, 
                          style: AppTextStyle.bodyMedium, 
                          fontWeight: FontWeight.bold,
                          color: doc.status == 'Expired' 
                              ? AppColors.error 
                              : (doc.status == 'Valid' ? AppColors.primary : AppColors.success)
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Bottom Row: Action buttons
          Row(
            children: [
              Expanded(
                child: doc.status == 'Expired'
                    ? SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                          label: const AppText('Renew Now', style: AppTextStyle.labelLarge, color: Colors.white, fontWeight: FontWeight.bold),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => controller.renewDocument(doc.title),
                        ),
                      )
                    : doc.status == 'Active'
                        ? SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.badge_outlined, color: isDark ? Colors.white : AppColors.primary, size: 18),
                              label: AppText('Digital ID', style: AppTextStyle.labelLarge, color: isDark ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF334155) : AppColors.primaryLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: controller.downloadDigitalId,
                            ),
                          )
                        : AppButton(
                            text: 'Preview',
                            icon: Icons.visibility_outlined,
                            height: 40,
                            onPressed: () => controller.previewDocument(doc.title),
                          ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => controller.previewDocument(doc.title),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.2) : AppColors.primaryLight.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    doc.status == 'Expired' ? Icons.edit_outlined : Icons.share_outlined, 
                    color: AppColors.primary, 
                    size: 18
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Section card wrapper
  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  AppText(title, style: AppTextStyle.bodyLarge, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ],
              ),
              if (actionText != null && onActionTap != null)
                GestureDetector(
                  onTap: onActionTap,
                  child: AppText(actionText, style: AppTextStyle.labelMedium, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Detail row item
  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: AppTextStyle.labelMedium, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        const SizedBox(height: 4),
        AppText(value, style: AppTextStyle.bodyLarge, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
      ],
    );
  }

  // Horizontal name-value row
  Widget _buildHorizontalRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(label, style: AppTextStyle.bodyMedium, color: AppColors.textSecondary),
        AppText(value, style: AppTextStyle.bodyMedium, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
      ],
    );
  }
}
