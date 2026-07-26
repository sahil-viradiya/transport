import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A picked image carried as bytes so it works identically on web and mobile
/// (web has no `dart:io` File — using bytes avoids the `_Namespace` error).
class PickedImage {
  final String name;
  final Uint8List bytes;
  const PickedImage(this.name, this.bytes);
}

class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedImage?> pickFromGallery() => _pick(ImageSource.gallery);

  static Future<PickedImage?> captureFromCamera() => _pick(ImageSource.camera);

  static Future<PickedImage?> _pick(ImageSource source) async {
    try {
      final XFile? image =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return null;
      return PickedImage(image.name, await image.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// Prompts the user with a modal bottom sheet to choose Gallery or Camera,
  /// then returns the selected image as a `data:image/jpeg;base64,...` URL string.
  static Future<String?> pickImageAsBase64(BuildContext context, bool isDark) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
              title: Text(
                'Take Photo with Camera',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final picked = source == ImageSource.gallery
        ? await pickFromGallery()
        : await captureFromCamera();

    if (picked == null || picked.bytes.isEmpty) return null;

    return 'data:image/jpeg;base64,${base64Encode(picked.bytes)}';
  }
}
