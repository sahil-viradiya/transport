import 'package:get/get.dart';
import '../controllers/clock_in_controller.dart';

class ClockInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClockInController>(
      () => ClockInController(),
    );
  }
}
