import 'package:flutter/material.dart';
import '../app/core/theme/app_colors.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final internalController = controller ?? TextEditingController();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: internalController,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: false,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? const Color(0xFF64748B) : AppColors.textHint,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: internalController,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  internalController.clear();
                  if (onChanged != null) onChanged!('');
                  if (onClear != null) onClear!();
                },
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
                  size: 20,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
