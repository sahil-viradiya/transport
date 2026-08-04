import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/routes/app_pages.dart';

class LocationPermissionController extends GetxController {
  final ClockInService _clockInService = Get.find<ClockInService>();
  final RxBool isLoading = false.obs;

  Future<void> requestLocationPermission() async {
    isLoading.value = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Prompt to enable location service
        await Geolocator.openLocationSettings();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('[LocationPermissionController] Error: $e');
    } finally {
      isLoading.value = false;
      await _clockInService.setLocationPermissionCompleted(true);
      Get.offNamed(Routes.CLOCK_IN);
    }
  }

  Future<void> skipPermission() async {
    await _clockInService.setLocationPermissionCompleted(true);
    Get.offNamed(Routes.CLOCK_IN);
  }
}
