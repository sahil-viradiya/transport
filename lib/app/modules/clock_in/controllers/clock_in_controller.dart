import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/data/services/location_service.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';

class ClockInController extends GetxController {
  final ClockInService clockInService = Get.find<ClockInService>();
  final SessionService sessionService = Get.find<SessionService>();
  final LocationService _locationService = Get.put(LocationService());

  final RxString driverName = 'Driver'.obs;
  final RxString driverPhone = ''.obs;
  final RxString driverAvatar = ''.obs;

  final RxString currentTimeString = ''.obs;
  final RxString currentDateString = ''.obs;
  final RxString selectedVehicle = 'GJ-01-AX-9988'.obs;
  final RxString currentLocationAddress = 'Fetching current location...'.obs;

  final RxBool isLoadingLocation = false.obs;
  final RxBool isClockingIn = false.obs;

  final List<String> availableVehicles = [
    'GJ-01-AX-9988 (16-Wheeler Multi-Axle)',
    'MH-12-PQ-4521 (14-Wheeler Container)',
    'KA-04-LM-7712 (10-Wheeler Cargo)',
    'DL-01-TT-3344 (Heavy Carrier)',
  ];

  Timer? _clockTimer;
  DateTime? _lastPressedAt;

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void onInit() {
    super.onInit();
    _loadDriverProfile();
    _startLiveClock();
    fetchCurrentLocation();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    super.onClose();
  }

  void _loadDriverProfile() {
    driverName.value = sessionService.name.value.isNotEmpty
        ? sessionService.name.value
        : 'Rajesh Kumar';
    driverPhone.value = sessionService.phone.value;
    driverAvatar.value = sessionService.avatarUrl.value;
  }

  void _startLiveClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateClock();
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final hStr = hour12.toString().padLeft(2, '0');
    final mStr = now.minute.toString().padLeft(2, '0');
    final sStr = now.second.toString().padLeft(2, '0');
    currentTimeString.value = '$hStr:$mStr:$sStr $amPm';

    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    currentDateString.value = '$weekday, $dayStr $month ${now.year}';
  }

  Future<void> fetchCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      final pos = await _locationService.getCurrentPosition();
      final address = await _locationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      currentLocationAddress.value = address;
    } catch (e) {
      currentLocationAddress.value = 'JNPT Freight Hub, Navi Mumbai';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> handleClockIn() async {
    if (isClockingIn.value) return;
    isClockingIn.value = true;

    try {
      final loc = currentLocationAddress.value;

      await clockInService.clockIn(
        vehicle: '',
        location: loc,
      );

      AppSnackBar.showSuccess(
        title: 'Duty Started 🚛',
        message: 'You are now Clocked In! Safe driving.',
      );

      // Navigate to Home dashboard
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      AppSnackBar.showError(
        title: 'Clock In Failed',
        message: 'Could not complete clock in. Please try again.',
      );
    } finally {
      isClockingIn.value = false;
    }
  }

  void handleBackPress() {
    if (clockInService.isClockedIn.value) {
      Get.offAllNamed(Routes.HOME);
      return;
    }

    final now = DateTime.now();
    final timeElapsed =
        _lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2);

    if (timeElapsed) {
      _lastPressedAt = now;
      AppSnackBar.showInfo(
        title: 'Exit App',
        message: 'Press back again to exit application.',
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    SystemNavigator.pop();
  }
}
