import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_text.dart';
import '../../app/core/theme/app_colors.dart';

class AppPopup {
  AppPopup._();

  static bool _isLoadingOpen = false;

  static Future<bool?> showConfirmation({
    required String title,
    required String description,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Get.dialog<bool>(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText(title.tr, style: AppTextStyle.headlineSmall),
        content: AppText(description.tr, style: AppTextStyle.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              try {
                Navigator.of(context).pop(false);
              } catch (_) {
                Get.back(result: false);
              }
              if (onCancel != null) onCancel();
            },
            child: AppText(
              cancelText.tr,
              style: AppTextStyle.labelLarge,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              try {
                Navigator.of(context).pop(true);
              } catch (_) {
                Get.back(result: true);
              }
              if (onConfirm != null) onConfirm();
            },
            child: AppText(
              confirmText.tr,
              style: AppTextStyle.labelLarge,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static void showLoading({String message = 'Loading...'}) {
    // If a loading dialog is already displayed, prevent opening duplicate overlapping dialogs.
    if (_isLoadingOpen) return;

    final context = Get.overlayContext ?? Get.context;
    if (context == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _isLoadingOpen = true;

    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                AppText(
                  message.tr,
                  style: AppTextStyle.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    ).then((_) {
      _isLoadingOpen = false;
    });
  }

  static void hideLoading() {
    if (_isLoadingOpen || (Get.isDialogOpen ?? false)) {
      _isLoadingOpen = false;
      try {
        final context = Get.overlayContext ?? Get.context;
        if (context != null && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else if (Get.isDialogOpen ?? false) {
          Get.back();
        }
      } catch (_) {
        try {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }
        } catch (_) {}
      }
    }
  }
}
