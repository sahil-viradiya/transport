import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/showcase_controller.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_text_field.dart';
import '../../../../widgets/app_search_bar.dart';
import '../../../../widgets/app_image_view.dart';
import '../../../../widgets/app_otp_field.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';
import '../../../../widgets/dialogs/app_bottom_sheet.dart';
import '../../../../widgets/dialogs/app_popup.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';

class ShowcaseView extends GetView<ShowcaseController> {
  const ShowcaseView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Reusable Components Showcase', style: AppTextStyle.headlineSmall),
        actions: [
          Obx(() => Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: controller.isOnline.value ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppText(
                  controller.isOnline.value ? 'Online' : 'Offline',
                  style: AppTextStyle.labelMedium,
                  color: Colors.white,
                ),
              )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colors and Typography Preview
            _buildSection(
              title: '1. Brand Colors & Typography',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildColorBadge('Primary\n#0052CC', AppColors.primary, Colors.white),
                      _buildColorBadge('Secondary\n#42526E', AppColors.secondary, Colors.white),
                      _buildColorBadge('Tertiary\n#FFAB00', AppColors.tertiary, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AppText('Headline Large (Inter 32 Bold)', style: AppTextStyle.headlineLarge),
                  const AppText('Headline Medium (Inter 24 Bold)', style: AppTextStyle.headlineMedium),
                  const AppText('Headline Small (Inter 20 Semi-Bold)', style: AppTextStyle.headlineSmall),
                  const AppText('Body Large (Inter 16 Regular)', style: AppTextStyle.bodyLarge),
                  const AppText('Body Medium (Inter 14 Regular)', style: AppTextStyle.bodyMedium),
                  const AppText('Label Large (Inter 14 Semi-Bold Accent)', style: AppTextStyle.labelLarge),
                ],
              ),
            ),

            // Buttons Section
            _buildSection(
              title: '2. Reusable Buttons (AppButton)',
              child: Obx(() => Column(
                    children: [
                      AppButton(
                        text: 'Primary Button',
                        onPressed: () => AppSnackBar.showInfo(title: 'Button Clicked', message: 'Primary button trigger'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'Secondary Button',
                        type: AppButtonType.secondary,
                        onPressed: () => AppSnackBar.showInfo(title: 'Button Clicked', message: 'Secondary button trigger'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'Inverted Button',
                        type: AppButtonType.inverted,
                        onPressed: () => AppSnackBar.showInfo(title: 'Button Clicked', message: 'Inverted button trigger'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'Outlined Button',
                        type: AppButtonType.outlined,
                        onPressed: () => AppSnackBar.showInfo(title: 'Button Clicked', message: 'Outlined button trigger'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'Load 3-Second Process',
                        isLoading: controller.isBtnLoading.value,
                        onPressed: controller.startLoadingButton,
                      ),
                    ],
                  )),
            ),

            // Inputs Section
            _buildSection(
              title: '3. Form Fields & Search (AppTextField / AppSearchBar)',
              child: Form(
                key: controller.formKey,
                child: Column(
                  children: [
                    AppSearchBar(
                      controller: controller.searchController,
                      hintText: 'Search for articles, routes...',
                      onChanged: (val) => AppLogger.d('Search: $val'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: controller.textController,
                      labelText: 'Username or Email',
                      hintText: 'e.g. sahil@example.com',
                      prefixIcon: Icons.email_outlined,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Username cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const AppTextField(
                      labelText: 'Password',
                      hintText: 'Enter secret passphrase',
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // OTP Field Section
            _buildSection(
              title: '4. Pin Code / OTP (AppOtpField)',
              child: Column(
                children: [
                  AppOtpField(
                    controller: controller.otpController,
                    length: 4,
                    onCompleted: (pin) {
                      AppSnackBar.showSuccess(title: 'OTP Entered', message: 'Completed pin code entry: $pin');
                    },
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Validate Pin Input',
                    type: AppButtonType.outlined,
                    onPressed: () {
                      if (controller.otpController.text.length < 4) {
                        AppSnackBar.showError(title: 'Validation Error', message: 'Please input full 4 digits.');
                      } else {
                        AppSnackBar.showSuccess(title: 'Validated', message: 'Successful OTP match!');
                      }
                    },
                  ),
                ],
              ),
            ),

            // Dialogs, Popups, and BottomSheets
            _buildSection(
              title: '5. Dialogs, Sheets, & Notifications',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton(
                    text: 'Trigger Toast / SnackBar',
                    isFullWidth: false,
                    onPressed: () {
                      AppSnackBar.showSuccess(title: 'Success!', message: 'Task operation completed with zero issues.');
                    },
                  ),
                  AppButton(
                    text: 'Trigger Custom Sheet',
                    isFullWidth: false,
                    onPressed: () {
                      AppBottomSheet.show(
                        title: 'BottomSheet Option Menu',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppText(
                              'This is a modern styled premium sheet. It fits perfectly matching the overall branding guidelines.',
                              style: AppTextStyle.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            AppButton(
                              text: 'Done & Dismiss',
                              onPressed: () => Get.back(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  AppButton(
                    text: 'Confirmation Dialog',
                    isFullWidth: false,
                    onPressed: () {
                      AppPopup.showConfirmation(
                        title: 'Discard items?',
                        description: 'Are you absolutely sure you want to discard these items?',
                        confirmText: 'Discard',
                        onConfirm: () => AppSnackBar.showInfo(title: 'Action confirmed', message: 'Items successfully discarded.'),
                      );
                    },
                  ),
                  AppButton(
                    text: 'Toggle Global Spinner',
                    isFullWidth: false,
                    onPressed: () {
                      AppPopup.showLoading(message: 'Saving preferences...');
                      Future.delayed(const Duration(seconds: 3), () {
                        AppPopup.hideLoading();
                        AppSnackBar.showSuccess(title: 'Success', message: 'Preferences updated successfully.');
                      });
                    },
                  ),
                ],
              ),
            ),

            // SharedPref Storage Section
            _buildSection(
              title: '6. Persistence Demo (SharedPref)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText('Stored Value: ', style: AppTextStyle.labelLarge),
                            Expanded(
                              child: AppText(
                                controller.savedValue.value,
                                style: AppTextStyle.bodyMedium,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Save Key',
                          onPressed: controller.saveToStorage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Clear Key',
                          type: AppButtonType.outlined,
                          onPressed: controller.clearStorage,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ImageView & PickImage Section
            _buildSection(
              title: '7. Media Utilities (AppImageView / ImagePicker)',
              child: Column(
                children: [
                  Obx(() => Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: controller.pickedImagePath.value.isEmpty
                            ? const AppImageView(
                                imagePath: 'https://picsum.photos/600/400', // Remote cached image test
                                borderRadius: 12,
                              )
                            : AppImageView(
                                imagePath: controller.pickedImagePath.value,
                                borderRadius: 12,
                              ),
                      )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Gallery Pick',
                          type: AppButtonType.secondary,
                          icon: Icons.photo_library_outlined,
                          onPressed: () => controller.pickImage(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Camera Capture',
                          type: AppButtonType.secondary,
                          icon: Icons.camera_alt_outlined,
                          onPressed: () => controller.pickImage(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // API fetch section
            _buildSection(
              title: '8. Network Requests (Dio Interceptor & Error Handler)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: controller.isApiLoading.value
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              )
                            : AppText(
                                controller.apiResponse.value,
                                style: AppTextStyle.bodyMedium,
                              ),
                      )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Test Successful API',
                          onPressed: controller.fetchSuccessPost,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Test Error API',
                          type: AppButtonType.outlined,
                          onPressed: controller.fetchErrorPost,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, style: AppTextStyle.headlineSmall),
              const Divider(height: 24, thickness: 1),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorBadge(String label, Color color, Color textColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AppText(
          label,
          style: AppTextStyle.labelMedium,
          color: textColor,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
