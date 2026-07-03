import 'package:get/get.dart';
import '../controllers/driver_detail_controller.dart';

class DriverDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DriverDetailController>(() => DriverDetailController());
  }
}
