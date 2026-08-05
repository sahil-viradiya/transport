import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

enum PickType { camera, gallery, pdf }

/// A picked image or document file carried as bytes so it works identically on web and mobile.
class PickedFileResult {
  final String name;
  final Uint8List bytes;
  final bool isPdf;
  const PickedFileResult(this.name, this.bytes, {this.isPdf = false});

  String get dataUrl {
    final mime = isPdf ? 'application/pdf' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}

class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedFileResult?> pickFromGallery() => _pickImage(ImageSource.gallery);

  static Future<PickedFileResult?> captureFromCamera() => _pickImage(ImageSource.camera);

  static Future<PickedFileResult?> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null) return null;
      return PickedFileResult(image.name, await image.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  static Future<PickedFileResult?> pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.bytes == null || file.bytes!.isEmpty) return null;
      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      return PickedFileResult(file.name, file.bytes!, isPdf: isPdf);
    } catch (_) {
      return null;
    }
  }

  /// Prompts the user with a modal bottom sheet to choose Camera, Gallery, or PDF/Document,
  /// then returns the selected file as a `data:...;base64,...` URL string.
  static Future<String?> pickImageAsBase64(BuildContext context, bool isDark, {bool allowPdf = true}) async {
    final source = await showModalBottomSheet<PickType>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
              title: Text(
                'Take Photo with Camera',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, PickType.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
              title: Text(
                'Choose Image from Gallery',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, PickType.gallery),
            ),
            if (allowPdf)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                title: Text(
                  'Upload PDF Document',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () => Navigator.pop(ctx, PickType.pdf),
              ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    PickedFileResult? picked;
    if (source == PickType.camera) {
      picked = await captureFromCamera();
    } else if (source == PickType.gallery) {
      picked = await pickFromGallery();
    } else if (source == PickType.pdf) {
      picked = await pickPdf();
    }

    if (picked == null || picked.bytes.isEmpty) return null;
    return picked.dataUrl;
  }
}
