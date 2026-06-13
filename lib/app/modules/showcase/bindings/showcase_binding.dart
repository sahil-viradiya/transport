import 'package:get/get.dart';
import '../controllers/showcase_controller.dart';

class ShowcaseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShowcaseController>(
      () => ShowcaseController(),
    );
  }
}
