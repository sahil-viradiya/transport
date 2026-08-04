import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'storage_service.dart';
import 'session_service.dart';
import 'firebase_service.dart';
import '../../routes/app_pages.dart';

/// Central service for tracking driver duty clock-in status and onboarding permission steps.
class ClockInService extends GetxService {
  final StorageService _storage;

  ClockInService({StorageService? storage})
      : _storage = storage ?? Get.find<StorageService>();

  static const _kIsClockedIn = 'driver_is_clocked_in';
  static const _kClockInTime = 'driver_clock_in_time';
  static const _kVehicleNumber = 'driver_vehicle_number';
  static const _kClockInLocation = 'driver_clock_in_location';
  static const _kNotifCompleted = 'driver_notif_perm_completed';
  static const _kLocCompleted = 'driver_loc_perm_completed';

  final RxBool isClockedIn = false.obs;
  final Rxn<DateTime> clockInTime = Rxn<DateTime>();
  final RxString vehicleNumber = ''.obs;
  final RxString clockInLocation = ''.obs;
  final RxBool notificationPermissionCompleted = false.obs;
  final RxBool locationPermissionCompleted = false.obs;
  final RxString shiftDurationText = '00h 00m'.obs;

  Timer? _shiftTimer;

  Future<ClockInService> init() async {
    isClockedIn.value = _storage.read<bool>(_kIsClockedIn) ?? false;
    vehicleNumber.value = _storage.read<String>(_kVehicleNumber) ?? 'GJ-01-AX-9988';
    clockInLocation.value = _storage.read<String>(_kClockInLocation) ?? '';
    notificationPermissionCompleted.value =
        _storage.read<bool>(_kNotifCompleted) ?? false;
    locationPermissionCompleted.value =
        _storage.read<bool>(_kLocCompleted) ?? false;

    final timeStr = _storage.read<String>(_kClockInTime);
    if (timeStr != null && timeStr.isNotEmpty) {
      try {
        clockInTime.value = DateTime.parse(timeStr);
      } catch (_) {
        clockInTime.value = null;
      }
    }

    if (isClockedIn.value) {
      _startShiftTimer();
    }
    return this;
  }

  void _startShiftTimer() {
    _shiftTimer?.cancel();
    _updateShiftDuration();
    _shiftTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateShiftDuration();
    });
  }

  void _updateShiftDuration() {
    if (!isClockedIn.value || clockInTime.value == null) {
      shiftDurationText.value = '00h 00m';
      return;
    }
    final diff = DateTime.now().difference(clockInTime.value!);
    final hours = diff.inHours;
    final mins = diff.inMinutes.remainder(60);
    shiftDurationText.value =
        '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }

  Future<void> setNotificationPermissionCompleted(bool val) async {
    notificationPermissionCompleted.value = val;
    await _storage.write(_kNotifCompleted, val);
  }

  Future<void> setLocationPermissionCompleted(bool val) async {
    locationPermissionCompleted.value = val;
    await _storage.write(_kLocCompleted, val);
  }

  /// Clock in driver for shift
  Future<void> clockIn({
    required String vehicle,
    required String location,
  }) async {
    final now = DateTime.now();
    isClockedIn.value = true;
    clockInTime.value = now;
    vehicleNumber.value = vehicle;
    clockInLocation.value = location;

    await _storage.write(_kIsClockedIn, true);
    await _storage.write(_kClockInTime, now.toIso8601String());
    await _storage.write(_kVehicleNumber, vehicle);
    await _storage.write(_kClockInLocation, location);

    _startShiftTimer();

    // Sync status to Firestore if user is authenticated
    try {
      if (Get.isRegistered<SessionService>() && Get.isRegistered<FirebaseService>()) {
        final session = Get.find<SessionService>();
        if (session.isLoggedIn && !session.isAdmin) {
          final firebase = Get.find<FirebaseService>();
          await firebase.updateDriverShiftStatus(
            isClockedIn: true,
            clockInTime: now,
            vehicleNumber: vehicle,
            location: location,
          );
        }
      }
    } catch (e) {
      debugPrint('[ClockInService] Sync to Firestore error: $e');
    }
  }

  /// Clock out driver
  Future<void> clockOut() async {
    _shiftTimer?.cancel();
    isClockedIn.value = false;
    clockInTime.value = null;
    shiftDurationText.value = '00h 00m';

    await _storage.write(_kIsClockedIn, false);
    await _storage.remove(_kClockInTime);

    // Sync status to Firestore
    try {
      if (Get.isRegistered<SessionService>() && Get.isRegistered<FirebaseService>()) {
        final session = Get.find<SessionService>();
        if (session.isLoggedIn && !session.isAdmin) {
          final firebase = Get.find<FirebaseService>();
          await firebase.updateDriverShiftStatus(
            isClockedIn: false,
            clockOutTime: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('[ClockInService] Clock out sync error: $e');
    }
  }

  /// Determine target initial route based on driver status
  String getInitialRoute() {
    try {
      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        if (session.isAdmin) {
          return Routes.ADMIN_HOME;
        }
      }
    } catch (_) {}

    if (!notificationPermissionCompleted.value) {
      return Routes.NOTIFICATION_PERMISSION;
    }

    if (!locationPermissionCompleted.value) {
      return Routes.LOCATION_PERMISSION;
    }

    if (!isClockedIn.value) {
      return Routes.CLOCK_IN;
    }

    return Routes.HOME;
  }
}
