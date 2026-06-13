import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/location_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<DashboardController>(() => DashboardController());
    Get.lazyPut<TripsController>(() => TripsController());
    Get.lazyPut<ProfileController>(() => ProfileController());
    Get.lazyPut<FirebaseService>(() => FirebaseService());
    Get.lazyPut<LocationService>(() => LocationService());
  }
}
