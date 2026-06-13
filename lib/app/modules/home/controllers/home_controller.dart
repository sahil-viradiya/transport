import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';

class HomeController extends GetxController {
  final RxInt currentIndex = 0.obs;
  DateTime? lastPressedAt;

  void changeTabIndex(int index) {
    currentIndex.value = index;
  }

  void handleBackPress() {
    if (currentIndex.value != 0) {
      changeTabIndex(0);
      return;
    }

    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrTimeHasElapsed =
        lastPressedAt == null || now.difference(lastPressedAt!) > const Duration(seconds: 2);

    if (backButtonHasNotBeenPressedOrTimeHasElapsed) {
      lastPressedAt = now;
      AppSnackBar.showInfo(
        title: 'Exit App',
        message: 'Press back again to exit.',
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    SystemNavigator.pop();
  }
}
