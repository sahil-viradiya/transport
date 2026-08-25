import 'package:flutter/material.dart';
import '../app/core/theme/app_colors.dart';
import '../app/core/utils/app_image_helper.dart';

class AppImageView extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String placeholderImage;
  final double borderRadius;
  final Color? color;

  const AppImageView({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderImage =
        'assets/images/placeholder.png', // Fallback local placeholder
    this.borderRadius = 0.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = AppImageHelper.buildImageWidget(
      source: imagePath,
      width: width,
      height: height,
      fit: fit,
      color: color,
      placeholder: _buildShimmer(),
      errorWidget: _buildPlaceholder(),
    );

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.secondaryLight.withValues(alpha: 0.5),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textHint,
          size: width != null ? (width! * 0.3).clamp(20, 50) : 30,
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: width,
      height: height,
      color: AppColors.secondaryLight.withValues(alpha: 0.5),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }
}

// Support legacy modes
typedef BlendColorFilterMode = BlendMode;
