import 'package:flutter/material.dart';

import '../app/core/theme/app_colors.dart';

/// Standard surface used by feature screens for bordered content groups.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isDark ? const Color(0xFF1F1B18) : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
            color: isDark ? const Color(0xFF332E2A) : AppColors.border),
      ),
      child: child,
    );
  }
}
