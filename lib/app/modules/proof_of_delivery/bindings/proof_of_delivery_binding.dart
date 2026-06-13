import 'package:get/get.dart';
import '../controllers/proof_of_delivery_controller.dart';

class ProofOfDeliveryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProofOfDeliveryController>(
      () => ProofOfDeliveryController(),
    );
  }
}
