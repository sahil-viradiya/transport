import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../../data/services/location_service.dart';

class TripDetailsBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure deps exist even when opened outside the driver Home shell
    // (e.g. an admin tapping a notification), so navigation never crashes.
    if (!Get.isRegistered<LocationService>()) {
      Get.lazyPut<LocationService>(() => LocationService());
    }
    if (!Get.isRegistered<TripsController>()) {
      Get.lazyPut<TripsController>(() => TripsController());
    }
    Get.lazyPut<TripDetailsController>(
      () => TripDetailsController(),
    );
  }
}
