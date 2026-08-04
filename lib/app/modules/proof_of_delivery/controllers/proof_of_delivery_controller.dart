import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/core/utils/image_picker_helper.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/session_service.dart';

class ProofOfDeliveryController extends GetxController {
  final remarksController = TextEditingController();

  // Picked image kept as bytes so preview + upload work on web and mobile.
  final Rx<Uint8List?> pickedBytes = Rx<Uint8List?>(null);
  bool get hasImage => pickedBytes.value != null;

  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;

  final RxString tripId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is Map) {
      if (args['tripId'] != null) {
        tripId.value = args['tripId'].toString();
      }
    }
  }

  // Action to pick photo using Camera
  Future<void> takePhoto() async {
    final img = await ImagePickerHelper.captureFromCamera();
    if (img != null) {
      pickedBytes.value = img.bytes;
    } else {
      AppSnackBar.showInfo(
        title: 'No Photo',
        message: 'No camera photo captured.',
      );
    }
  }

  // Action to pick photo from Gallery
  Future<void> fromGallery() async {
    final img = await ImagePickerHelper.pickFromGallery();
    if (img != null) {
      pickedBytes.value = img.bytes;
    } else {
      AppSnackBar.showInfo(
        title: 'No Photo',
        message: 'No gallery photo selected.',
      );
    }
  }

  // Action to pick PDF Document
  Future<void> fromPdf() async {
    final pdf = await ImagePickerHelper.pickPdf();
    if (pdf != null && pdf.bytes.isNotEmpty) {
      pickedBytes.value = pdf.bytes;
    } else {
      AppSnackBar.showInfo(
        title: 'No Document',
        message: 'No PDF document selected.',
      );
    }
  }

  // Delete/Clear picked photo
  void deletePhoto() {
    pickedBytes.value = null;
    uploadProgress.value = 0.0;
    isUploading.value = false;
  }

  // Server upload logic linked with Firebase Storage & Firestore
  Future<void> submitProof() async {
    if (!hasImage) {
      AppSnackBar.showWarning(
        title: 'No Document Found',
        message: 'Please take a photo or choose a document scan first.',
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    final locationService = Get.find<LocationService>();
    try {
      await locationService.checkLocationAccess();
    } catch (e) {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      return;
    }

    // Simulate progress updates during actual upload
    const totalSteps = 5;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      uploadProgress.value =
          (i / totalSteps) * 0.7; // Go up to 70% during simulation prep
    }

    String finalUrl = '';
    try {
      final firebaseService = Get.find<FirebaseService>();

      final pos = await locationService.getCurrentPosition();
      final currentLat = pos.latitude;
      final currentLng = pos.longitude;
      final currentAddr = await locationService.getAddressFromCoordinates(
          currentLat, currentLng);

      finalUrl = await firebaseService.uploadProofOfDelivery(
          tripId.value, pickedBytes.value);
      uploadProgress.value = 0.9;
      await firebaseService.saveProofOfDeliveryDetails(
        tripId.value,
        finalUrl,
        remarksController.text,
        locationName: currentAddr,
        latitude: currentLat,
        longitude: currentLng,
      );

      String driverName = '';
      try {
        driverName = Get.find<SessionService>().name.value;
      } catch (_) {}

      // Formally request delivery approval to transition status to DELIVERY_REQUESTED
      await firebaseService.requestDelivery(
        tripId.value,
        location: currentAddr,
        latitude: currentLat,
        longitude: currentLng,
        driverName: driverName,
      );
    } catch (e) {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      AppSnackBar.showError(title: 'Submission Failed', message: e.toString());
      return;
    }

    uploadProgress.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 200));

    isUploading.value = false;
    if (finalUrl.startsWith('http')) {
      AppSnackBar.showSuccess(
        title: 'Upload Successful',
        message: 'Proof of delivery submitted successfully. Trip completed!',
      );
      Get.back(result: true);
    } else {
      AppSnackBar.showWarning(
        title: 'Saved Locally (Fallback)',
        message:
            'Firebase Storage bucket not initialized. Proof of delivery saved locally on device.',
      );
    }

    // Navigate back to the home page or trips list
    await Future.delayed(const Duration(seconds: 1));
    Get.back(result: true);
  }

  @override
void onClose() {
    remarksController.dispose();
    super.onClose();
  }
}
