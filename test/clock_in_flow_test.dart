import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/routes/app_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClockInService & Onboarding Flow Tests', () {
    late StorageService storageService;
    late ClockInService clockInService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();

      storageService = StorageService();
      await storageService.init();
      Get.put<StorageService>(storageService);

      final sessionService = SessionService(storage: storageService);
      await sessionService.init();
      Get.put<SessionService>(sessionService);

      clockInService = ClockInService(storage: storageService);
      await clockInService.init();
      Get.put<ClockInService>(clockInService);
    });

    test('Initial route returns NOTIFICATION_PERMISSION when onboarding incomplete', () {
      expect(clockInService.getInitialRoute(), Routes.NOTIFICATION_PERMISSION);
    });

    test('Initial route advances to LOCATION_PERMISSION after notification step completed', () async {
      await clockInService.setNotificationPermissionCompleted(true);
      expect(clockInService.getInitialRoute(), Routes.LOCATION_PERMISSION);
    });

    test('Initial route advances to CLOCK_IN after location step completed', () async {
      await clockInService.setNotificationPermissionCompleted(true);
      await clockInService.setLocationPermissionCompleted(true);
      expect(clockInService.getInitialRoute(), Routes.CLOCK_IN);
    });

    test('Clock in sets state and initial route becomes HOME', () async {
      await clockInService.setNotificationPermissionCompleted(true);
      await clockInService.setLocationPermissionCompleted(true);

      await clockInService.clockIn(
        vehicle: 'GJ-01-AX-9988',
        location: 'JNPT Freight Hub',
      );

      expect(clockInService.isClockedIn.value, true);
      expect(clockInService.vehicleNumber.value, 'GJ-01-AX-9988');
      expect(clockInService.clockInLocation.value, 'JNPT Freight Hub');
      expect(clockInService.getInitialRoute(), Routes.HOME);
    });

    test('Clock out clears state and initial route reverts to CLOCK_IN', () async {
      await clockInService.setNotificationPermissionCompleted(true);
      await clockInService.setLocationPermissionCompleted(true);

      await clockInService.clockIn(
        vehicle: 'GJ-01-AX-9988',
        location: 'JNPT Freight Hub',
      );

      await clockInService.clockOut();

      expect(clockInService.isClockedIn.value, false);
      expect(clockInService.getInitialRoute(), Routes.CLOCK_IN);
    });
  });
}
