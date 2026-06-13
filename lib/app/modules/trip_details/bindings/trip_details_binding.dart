import 'package:get/get.dart';
import '../controllers/trip_details_controller.dart';

class TripDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TripDetailsController>(
      () => TripDetailsController(),
    );
  }
}
