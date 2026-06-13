import 'package:flutter/material.dart';
import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

enum AppButtonType {
  primary,
  secondary,
  outlined,
  inverted,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final double? width;
  final double height;
  final IconData? icon;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.icon,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color buttonColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case AppButtonType.primary:
        buttonColor = AppColors.primary;
        textColor = Colors.white;
        break;
      case AppButtonType.secondary:
        buttonColor = isDark ? const Color(0xFF334155) : AppColors.secondaryLight;
        textColor = isDark ? Colors.white : AppColors.secondary;
        break;
      case AppButtonType.inverted:
        buttonColor = isDark ? Colors.white : AppColors.secondaryDark;
        textColor = isDark ? AppColors.secondaryDark : Colors.white;
        break;
      case AppButtonType.outlined:
        buttonColor = Colors.transparent;
        textColor = isDark ? Colors.white : AppColors.primary;
        borderSide = BorderSide(
          color: isDark ? const Color(0xFF475569) : AppColors.primary,
          width: 1.5,
        );
        break;
    }

    final isButtonDisabled = onPressed == null || isLoading;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == AppButtonType.outlined ? AppColors.primary : textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: isButtonDisabled ? theme.disabledColor : textColor,
          ),
          const SizedBox(width: 8),
        ],
        AppText(
          text,
          style: AppTextStyle.labelLarge,
          color: isButtonDisabled ? theme.disabledColor : textColor,
        ),
      ],
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: buttonColor,
      disabledBackgroundColor: isDark
          ? const Color(0xFF1E293B)
          : AppColors.secondaryLight.withOpacity(0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );

    Widget button = SizedBox(
      height: height,
      width: isFullWidth ? (width ?? double.infinity) : width,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isButtonDisabled ? null : onPressed,
        child: content,
      ),
    );

    // Minor micro-animation scale effect when hovered/pressed
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      child: button,
    );
  }
}
