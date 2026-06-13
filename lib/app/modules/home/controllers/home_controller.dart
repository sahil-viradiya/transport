import 'package:get/get.dart';

class HomeController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTabIndex(int index) {
    currentIndex.value = index;
  }
}
