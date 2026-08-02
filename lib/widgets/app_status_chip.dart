import 'package:flutter/material.dart';

/// Compact, theme-safe status label. The feature supplies status semantics.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
