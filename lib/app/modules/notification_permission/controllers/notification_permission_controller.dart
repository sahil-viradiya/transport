import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/routes/app_pages.dart';

class NotificationPermissionController extends GetxController {
  final ClockInService _clockInService = Get.find<ClockInService>();
  final RxBool isLoading = false.obs;

  Future<void> requestNotificationPermission() async {
    isLoading.value = true;
    try {
      if (!kIsWeb) {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
    } catch (e) {
      debugPrint('[NotificationPermissionController] Request error: $e');
    } finally {
      isLoading.value = false;
      await _clockInService.setNotificationPermissionCompleted(true);
      Get.offNamed(Routes.LOCATION_PERMISSION);
    }
  }

  Future<void> skipPermission() async {
    await _clockInService.setNotificationPermissionCompleted(true);
    Get.offNamed(Routes.LOCATION_PERMISSION);
  }
}
