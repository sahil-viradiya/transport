import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_text.dart';
import '../../app/core/theme/app_colors.dart';

class AppPopup {
  AppPopup._();

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
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
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
    );
  }

  static void hideLoading() {
    if (Get.isDialogOpen ?? false) {
      try {
        final context = Get.overlayContext ?? Get.context;
        if (context != null) {
          Navigator.of(context).pop();
        } else {
          Get.back();
        }
      } catch (_) {
        try {
          Get.back();
        } catch (_) {}
      }
    }
  }
}
