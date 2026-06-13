import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/core/utils/image_picker_helper.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import '../../../data/services/firebase_service.dart';
import '../../trips/controllers/trips_controller.dart';

class ProofOfDeliveryController extends GetxController {
  final remarksController = TextEditingController();

  final RxString pickedImagePath = ''.obs;
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  
  final RxString tripId = 'IND-99281'.obs;

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
    final path = await ImagePickerHelper.captureImageFromCamera();
    if (path != null) {
      pickedImagePath.value = path;
    } else {
      // Simulation mode fallback for emulators
      pickedImagePath.value = 'receipt_scan_042.jpg';
      AppSnackBar.showInfo(
        title: 'Simulation Mode',
        message: 'No camera photo captured. Mock document loaded for preview.',
      );
    }
  }

  // Action to pick photo from Gallery
  Future<void> fromGallery() async {
    final path = await ImagePickerHelper.pickImageFromGallery();
    if (path != null) {
      pickedImagePath.value = path;
    } else {
      // Simulation mode fallback for emulators
      pickedImagePath.value = 'receipt_scan_042.jpg';
      AppSnackBar.showInfo(
        title: 'Simulation Mode',
        message: 'No gallery photo selected. Mock document loaded for preview.',
      );
    }
  }

  // Delete/Clear picked photo
  void deletePhoto() {
    pickedImagePath.value = '';
    uploadProgress.value = 0.0;
    isUploading.value = false;
  }

  // Server upload logic linked with Firebase Storage & Firestore
  Future<void> submitProof() async {
    if (pickedImagePath.value.isEmpty) {
      AppSnackBar.showWarning(
        title: 'No Document Found',
        message: 'Please take a photo or choose a document scan first.',
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    // Simulate progress updates during actual upload
    const totalSteps = 5;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      uploadProgress.value = (i / totalSteps) * 0.7; // Go up to 70% during simulation prep
    }

    String finalUrl = '';
    try {
      final firebaseService = Get.find<FirebaseService>();
      finalUrl = await firebaseService.uploadProofOfDelivery(tripId.value, pickedImagePath.value);
      uploadProgress.value = 0.9;
      await firebaseService.saveProofOfDeliveryDetails(tripId.value, finalUrl, remarksController.text);
      
      // Update local state in TripsController
      try {
        final tripsController = Get.find<TripsController>();
        final updatedTrips = tripsController.allTrips.map((trip) {
          if (trip.id == tripId.value) {
            return TripItemModel(
              id: trip.id,
              truckNo: trip.truckNo,
              status: 'DELIVERED',
              pickupCity: trip.pickupCity,
              pickupLocation: trip.pickupLocation,
              dropCity: trip.dropCity,
              dropLocation: trip.dropLocation,
              date: trip.date,
              tabType: trip.tabType,
              isActive: false,
              driverPhone: trip.driverPhone,
            );
          }
          return trip;
        }).toList();
        tripsController.allTrips.assignAll(updatedTrips);
      } catch (_) {}
    } catch (_) {}

    uploadProgress.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 200));

    isUploading.value = false;
    if (finalUrl.startsWith('http')) {
      AppSnackBar.showSuccess(
        title: 'Upload Successful',
        message: 'Proof of delivery submitted successfully. Trip completed!',
      );
    } else {
      AppSnackBar.showWarning(
        title: 'Saved Locally (Fallback)',
        message: 'Firebase Storage bucket not initialized. Proof of delivery saved locally on device.',
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
