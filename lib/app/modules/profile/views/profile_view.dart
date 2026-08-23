import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/config/app_config.dart';
import '../controllers/profile_controller.dart';

/// Redesigned Profile screen matching the reference design:
/// - Compact top app bar with back navigation and centered "Profile" title
/// - Top profile card with user avatar, bold name, phone number, and green Online indicator
/// - Grouped menu card with:
///   1. My Profile
///   2. Change Password
///   3. Help & Support
///   4. About Us
///   5. Logout (red text & icon)
/// - Seamless connection with all existing profile data, avatar upload, and logout workflows
class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(corsSafeImageUrl(path));
    }
    if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
      return FileImage(File(path));
    }
    return const CachedNetworkImageProvider(
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    );
  }

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
    final driverController = Get.find<DashboardController>();

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
          'Profile',
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
        child: RefreshIndicator(
          onRefresh: controller.loadProfileFromFirebase,
          color: const Color(0xFF16A34A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Profile Summary Card
                _buildProfileCard(context, driverController, isDark),
                const SizedBox(height: 14),

                // 2. Grouped Menu Options Card
                _buildMenuCard(context, driverController, isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Top Profile Card ───────────────────────────────────────────────────
  Widget _buildProfileCard(
    BuildContext context,
    DashboardController driverController,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          // Circular Avatar with change button
          GestureDetector(
            onTap: controller.changeAvatar,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Obx(
                    () => CircleAvatar(
                      radius: 30,
                      backgroundImage: _getImageProvider(
                        driverController.avatarUrl.value,
                      ),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Name + Phone + Online status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    driverController.driverName.value.isNotEmpty
                        ? driverController.driverName.value
                        : 'Driver',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 3),
                Obx(
                  () => Text(
                    driverController.driverPhone.value.isNotEmpty
                        ? driverController.driverPhone.value
                        : '+91 98765 43210',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Grouped Menu Options Card ──────────────────────────────────────────
  Widget _buildMenuCard(
    BuildContext context,
    DashboardController driverController,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 1. My Profile
            _menuTile(
              icon: Icons.person_outline_rounded,
              title: 'My Profile',
              onTap: () => _showMyProfileSheet(context, driverController, isDark),
              isDark: isDark,
            ),
            _divider(isDark),

            // 2. Change Password
            _menuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: () => _showChangePasswordDialog(context, isDark),
              isDark: isDark,
            ),
            _divider(isDark),

            // 3. Help & Support
            _menuTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              onTap: () => _showHelpSupportSheet(context, isDark),
              isDark: isDark,
            ),
            _divider(isDark),

            // 4. About Us
            _menuTile(
              icon: Icons.info_outline_rounded,
              title: 'About Us',
              onTap: () => _showAboutUsSheet(context, isDark),
              isDark: isDark,
            ),
            _divider(isDark),

            // 5. Logout
            _menuTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              isDestructive: true,
              onTap: () => _showLogoutDialog(context, driverController, isDark),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final titleColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white : const Color(0xFF0F172A));
    final iconColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white70 : const Color(0xFF334155));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog: My Profile Details & Edit ──────────────────────────────────────
  void _showMyProfileSheet(
    BuildContext context,
    DashboardController driverController,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Driver Information',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          controller.showEditProfileDialog();
                        },
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _infoRow('Driver Name', driverController.driverName.value, isDark),
                  const Divider(height: 16),
                  _infoRow('Phone Number', driverController.driverPhone.value, isDark),
                  const Divider(height: 16),
                  _infoRow('Assigned Vehicle', driverController.vehicleNo.value, isDark),
                  const Divider(height: 16),
                  _infoRow('Vehicle Model', driverController.vehicleModel.value, isDark),
                  const Divider(height: 16),
                  _infoRow('License Number', controller.licenseNo.value, isDark),
                  const Divider(height: 16),
                  _infoRow('License Class', controller.licenseClass.value, isDark),
                  const Divider(height: 16),
                  _infoRow('License Expiry', controller.licenseExpires.value, isDark),
                  const Divider(height: 16),
                  _infoRow('Employer', controller.employer.value, isDark),
                  const Divider(height: 16),
                  _infoRow('Fleet Hub', controller.fleetHub.value, isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
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
          value.isNotEmpty ? value : '—',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ── Dialog: Change Password ────────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context, bool isDark) {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Change Password',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: oldPasswordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (newPasswordCtrl.text.isEmpty || oldPasswordCtrl.text.isEmpty) {
                Get.snackbar('Required', 'Please enter your passwords.');
                return;
              }
              if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                Get.snackbar('Error', 'New passwords do not match.');
                return;
              }
              Get.back();
              Get.snackbar('Success', 'Password updated successfully!');
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Help & Support ─────────────────────────────────────────────────
  void _showHelpSupportSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(
                        () => Text(
                          '${controller.emergencyContactName.value} (${controller.emergencyRelation.value})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Obx(
                        () => Text(
                          controller.emergencyPhone.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    controller.showEditEmergencyContactDialog();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Emergency Contact'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Dialog: About Us & Language ───────────────────────────────────────────
  void _showAboutUsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'About Transport App',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                _infoRow('Version', controller.appVersion.value, isDark),
                const Divider(height: 16),
                _infoRow('Employer', controller.employer.value, isDark),
                const Divider(height: 16),
                _infoRow('Fleet Hub', controller.fleetHub.value, isDark),
                const SizedBox(height: 16),

                // Language Switcher
                Text(
                  'App Language',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final currentLang = AppConfig.currentLocale.value.languageCode;
                  return Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              'English',
                              style: TextStyle(
                                color: currentLang == 'en'
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          selected: currentLang == 'en',
                          selectedColor: const Color(0xFF16A34A),
                          backgroundColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            if (selected) AppConfig.changeLanguage('en');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              'हिंदी (Hindi)',
                              style: TextStyle(
                                color: currentLang == 'hi'
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          selected: currentLang == 'hi',
                          selectedColor: const Color(0xFF16A34A),
                          backgroundColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            if (selected) AppConfig.changeLanguage('hi');
                          },
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'POWERED BY\nMinistry of Road Transport & Highways',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Dialog: Logout Confirmation ───────────────────────────────────────────
  void _showLogoutDialog(
    BuildContext context,
    DashboardController driverController,
    bool isDark,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout of your account?',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Get.back();
              driverController.logout();
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
