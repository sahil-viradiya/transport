import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import '../../../widgets/dialogs/app_snackbar.dart';

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  
  final RxBool isConnected = true.obs;
  bool _isInitialCheck = true;

  Future<ConnectivityService> init() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    return this;
  }

  Future<void> checkCurrentConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    final previousConnection = isConnected.value;
    isConnected.value = hasConnection;

    if (!hasConnection) {
      if (previousConnection && !_isInitialCheck) {
        AppSnackBar.showError(
          title: 'Connection Lost',
          message: 'Please check your internet connection.',
          position: SnackPosition.BOTTOM,
        );
      }
    } else {
      if (!previousConnection && !_isInitialCheck) {
        AppSnackBar.showSuccess(
          title: 'Connection Restored',
          message: 'You are back online.',
          position: SnackPosition.BOTTOM,
        );
      }
    }
    _isInitialCheck = false;
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }
}
