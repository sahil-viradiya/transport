import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../trips/controllers/trips_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<DashboardController>(() => DashboardController());
    Get.lazyPut<TripsController>(() => TripsController());
  }
}
