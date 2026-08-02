import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/core/theme/app_colors.dart';

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
    this.placeholderImage = 'assets/images/placeholder.png', // Fallback local placeholder
    this.borderRadius = 0.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imagePath.isEmpty) {
      imageWidget = _buildPlaceholder();
    } else if (imagePath.startsWith('data:image/')) {
      try {
        final base64String =
            imagePath.contains(',') ? imagePath.split(',')[1] : imagePath;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (_) {
        imageWidget = _buildPlaceholder();
      }
    } else if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
      // Remote Network Image with Caching
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        color: color,
        placeholder: (context, url) => _buildShimmer(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    } else if (imagePath.startsWith('assets/')) {
      // Local Assets (SVG or Normal Image)
      if (imagePath.endsWith('.svg')) {
        imageWidget = SvgPicture.asset(
          imagePath,
          width: width,
          height: height,
          fit: fit,
          colorFilter: color != null ? ColorFilter.mode(color!, BlendColorFilterMode.srcIn) : null,
        );
      } else {
        imageWidget = Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    } else if (!kIsWeb && File(imagePath).existsSync()) {
      // Local File Image (mobile/desktop only — File is unsupported on web)
      imageWidget = Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      imageWidget = _buildPlaceholder();
    }

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
