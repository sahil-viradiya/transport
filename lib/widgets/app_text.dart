import 'package:flutter/material.dart';

enum AppTextStyle {
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  bodyLarge,
  bodyMedium,
  labelLarge,
  labelMedium,
}

class AppText extends StatelessWidget {
  final String text;
  final AppTextStyle style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? fontSize;
  final FontWeight? fontWeight;

  const AppText(
    this.text, {
    super.key,
    this.style = AppTextStyle.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle textStyle;

    switch (style) {
      case AppTextStyle.headlineLarge:
        textStyle = theme.textTheme.headlineLarge!;
        break;
      case AppTextStyle.headlineMedium:
        textStyle = theme.textTheme.headlineMedium!;
        break;
      case AppTextStyle.headlineSmall:
        textStyle = theme.textTheme.headlineSmall!;
        break;
      case AppTextStyle.titleLarge:
        textStyle = theme.textTheme.titleLarge!;
        break;
      case AppTextStyle.bodyLarge:
        textStyle = theme.textTheme.bodyLarge!;
        break;
      case AppTextStyle.bodyMedium:
        textStyle = theme.textTheme.bodyMedium!;
        break;
      case AppTextStyle.labelLarge:
        textStyle = theme.textTheme.labelLarge!;
        break;
      case AppTextStyle.labelMedium:
        textStyle = theme.textTheme.labelMedium!;
        break;
    }

    // Apply custom overrides
    textStyle = textStyle.copyWith(
      color: color ?? textStyle.color,
      fontSize: fontSize ?? textStyle.fontSize,
      fontWeight: fontWeight ?? textStyle.fontWeight,
    );

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: textStyle,
    );
  }
}
