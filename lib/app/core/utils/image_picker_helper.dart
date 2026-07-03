import 'dart:typed_data';
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
}
