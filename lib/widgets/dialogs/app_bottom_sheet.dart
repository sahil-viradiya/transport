import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_text.dart';

class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Get.bottomSheet<T>(
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(
          top: 10,
          left: 20,
          right: 20,
          bottom: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            if (enableDrag)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFDFE1E6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null) ...[
              AppText(
                title,
                style: AppTextStyle.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            // Content
            Flexible(child: child),
          ],
        ),
      ),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
    );
  }

  // Helper for choice sheets
  static Future<T?> showOptions<T>({
    required String title,
    required List<BottomSheetOption<T>> options,
  }) {
    return show<T>(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          return ListTile(
            leading: opt.icon != null ? Icon(opt.icon) : null,
            title: AppText(opt.title, style: AppTextStyle.bodyLarge),
            onTap: () => Get.back(result: opt.value),
          );
        }).toList(),
      ),
    );
  }
}

class BottomSheetOption<T> {
  final String title;
  final T value;
  final IconData? icon;

  const BottomSheetOption({
    required this.title,
    required this.value,
    this.icon,
  });
}
