import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  // Pick single image from gallery
  static Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      return image?.path;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  // Capture single image using camera
  static Future<String?> captureImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      return image?.path;
    } catch (e) {
      print('Error capturing image from camera: $e');
      return null;
    }
  }

  // Pick multiple images from gallery
  static Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      return images.map((image) => image.path).toList();
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }
}
