import 'package:get/get.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/routes/app_pages.dart';

class SplashController extends GetxController {
  final _session = Get.find<SessionService>();

  final RxDouble loadingProgress = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _startProgressLoader();
  }

  void _startProgressLoader() {
    // Simulate loading progress bar
    const totalSteps = 30;
    var currentStep = 0;

    // Periodically update progress until 3 seconds pass
    const duration = Duration(milliseconds: 100);

    Future.doWhile(() async {
      await Future.delayed(duration);
      currentStep++;
      loadingProgress.value = currentStep / totalSteps;

      if (currentStep >= totalSteps) {
        _checkLoginStatus();
        return false;
      }
      return true;
    });
  }

  void _checkLoginStatus() {
    if (_session.isLoggedIn) {
      if (_session.isAdmin) {
        Get.offAllNamed(Routes.ADMIN_HOME);
      } else {
        Get.offAllNamed(Routes.HOME);
      }
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}
