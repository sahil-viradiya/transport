import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_url.dart';

/// Centralized, bulletproof image decoding and rendering utility.
/// Handles raw Base64, data:image URIs, local files, file:// URIs, blob URIs, network URLs, and assets.
class AppImageHelper {
  AppImageHelper._();

  /// Robustly decodes any Base64 image string (with or without data:image prefix, URL encoding, or whitespace).
  static Uint8List? decodeBase64(String input) {
    if (input.trim().isEmpty) return null;
    try {
      var str = input.trim();
      // Remove data URI scheme prefix if present
      if (str.contains(',')) {
        str = str.split(',').last.trim();
      }
      // Decode URL encoding if present (%2B -> +, %2F -> /, %3D -> =)
      if (str.contains('%')) {
        try {
          str = Uri.decodeComponent(str);
        } catch (_) {}
      }
      // Remove all whitespace and linebreaks
      str = str.replaceAll(RegExp(r'\s+'), '');
      if (str.isEmpty) return null;

      // Fix padding if missing
      while (str.length % 4 != 0) {
        str += '=';
      }

      final bytes = base64Decode(str);
      return bytes.isNotEmpty ? bytes : null;
    } catch (e) {
      return null;
    }
  }

  /// Determines if a given string is Base64 image data or raw Base64 bytes.
  static bool isBase64Image(String input) {
    if (input.trim().isEmpty) return false;
    final str = input.trim();
    if (str.startsWith('data:image/')) return true;
    if (str.startsWith('http://') ||
        str.startsWith('https://') ||
        str.startsWith('blob:') ||
        str.startsWith('/') ||
        str.startsWith('file://') ||
        str.startsWith('assets/')) {
      return false;
    }
    // Check common base64 image magic headers
    if (str.startsWith('/9j/') ||
        str.startsWith('iVBORw') ||
        str.startsWith('R0lGOD') ||
        str.startsWith('UklGR') ||
        str.startsWith('PHN2Zw')) {
      return true;
    }
    // Fallback attempt decode check for long string without spaces/slashes
    if (str.length > 30 && decodeBase64(str) != null) {
      return true;
    }
    return false;
  }

  /// Transforms any image source into a high-performance Flutter Widget.
  static Widget buildImageWidget({
    required String source,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    Color? color,
  }) {
    final raw = source.trim();

    Widget defaultError = errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
          ),
        );

    Widget defaultLoading = placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

    if (raw.isEmpty) return defaultError;

    // 1. Browser Blob URI (Flutter Web local upload preview)
    if (raw.startsWith('blob:')) {
      return Image.network(
        raw,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (_, __, ___) => defaultError,
      );
    }

    // 2. Local File Path (or file:// URI)
    if (!kIsWeb && (raw.startsWith('/') || raw.startsWith('file://'))) {
      String path = raw;
      if (path.startsWith('file://')) {
        try {
          path = Uri.parse(path).toFilePath();
        } catch (_) {
          path = path.replaceFirst('file://', '');
        }
      }
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            color: color,
            errorBuilder: (_, __, ___) {
              // Try base64 fallback if file path failed
              final bytes = decodeBase64(raw);
              if (bytes != null && bytes.isNotEmpty) {
                return Image.memory(bytes, width: width, height: height, fit: fit, color: color);
              }
              return defaultError;
            },
          );
        }
      } catch (_) {}
    }

    // 3. Base64 Image (data:image or raw base64)
    if (isBase64Image(raw) || raw.startsWith('data:image')) {
      final bytes = decodeBase64(raw);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (_, __, ___) => defaultError,
        );
      }
    }

    // 4. Asset Image
    if (raw.startsWith('assets/')) {
      return Image.asset(
        raw,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (_, __, ___) => defaultError,
      );
    }

    // 5. HTTP / HTTPS Network URL (bypasses Web CORS via proxy + multi-level fallback)
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final safeUrl = corsSafeImageUrl(raw);
      return CachedNetworkImage(
        imageUrl: safeUrl,
        width: width,
        height: height,
        fit: fit,
        color: color,
        placeholder: (_, __) => defaultLoading,
        errorWidget: (_, __, ___) {
          // Direct fallback attempt using Image.network with original raw URL
          return Image.network(
            raw,
            width: width,
            height: height,
            fit: fit,
            color: color,
            errorBuilder: (_, __, ___) {
              // Retry Base64 if URL string contained encoded base64
              final bytes = decodeBase64(raw);
              if (bytes != null && bytes.isNotEmpty) {
                return Image.memory(bytes, width: width, height: height, fit: fit, color: color);
              }
              return defaultError;
            },
          );
        },
      );
    }

    // 6. Ultimate Fallback: Try decoding as raw Base64 if string is not empty
    final fallbackBytes = decodeBase64(raw);
    if (fallbackBytes != null && fallbackBytes.isNotEmpty) {
      return Image.memory(
        fallbackBytes,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (_, __, ___) => defaultError,
      );
    }

    return defaultError;
  }
}
