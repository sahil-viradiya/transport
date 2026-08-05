import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/core/theme/app_colors.dart';

class AppSnackBar {
  AppSnackBar._();

  static void showSuccess({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.TOP,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.success,
      icon: Icons.check_circle_outline_rounded,
      position: position,
    );
  }

  static void showError({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.TOP,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline_rounded,
      position: position,
    );
  }

  static void showWarning({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.TOP,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
      position: position,
    );
  }

  static void showInfo({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.TOP,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.info,
      icon: Icons.info_outline_rounded,
      position: position,
    );
  }

  static void _show({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required SnackPosition position,
  }) {
    if (Get.overlayContext == null) return;
    Get.rawSnackbar(
      titleText: Text(
        title.tr,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      messageText: Text(
        message.tr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      icon: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
      backgroundColor: backgroundColor,
      snackPosition: position,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 8,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeIn,
    );
  }
}
