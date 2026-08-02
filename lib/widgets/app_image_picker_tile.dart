import 'package:flutter/material.dart';

import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

/// Presentation-only trigger for an image-picker action.
class AppImagePickerTile extends StatelessWidget {
  const AppImagePickerTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_a_photo_outlined,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.primary),
        label: AppText(label, style: AppTextStyle.labelLarge),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary),
        ),
      );
}
