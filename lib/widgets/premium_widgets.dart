import 'package:flutter/material.dart';
import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

/// A frosted stat tile used inside the saffron hero header (white text on
/// translucent white over the gradient).
class HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const HeroStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(value,
                    style: AppTextStyle.titleLarge,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                AppText(label,
                    style: AppTextStyle.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    color: Colors.white.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable rounded action tile for the dashboard quick-actions grid.
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1B18) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark ? const Color(0xFF332E2A) : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            AppText(label,
                style: AppTextStyle.labelMedium,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional trailing action label.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: AppText(title,
              style: AppTextStyle.headlineSmall,
              fontWeight: FontWeight.w700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: AppText(actionLabel!,
                style: AppTextStyle.labelLarge,
                color: AppColors.primary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
