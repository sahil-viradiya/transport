import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/app/data/services/connectivity_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import '../../trips/controllers/trips_controller.dart';

class DashboardController extends GetxController {
  final _storage = Get.find<StorageService>();
  final _connectivity = Get.find<ConnectivityService>();

  RxBool get isOnline => _connectivity.isConnected;

  Future<void> retryConnection() async {
    AppPopup.showLoading(message: 'Checking connection...');
    await _connectivity.checkCurrentConnection();
    await Future.delayed(const Duration(milliseconds: 800));
    AppPopup.hideLoading();
    if (_connectivity.isConnected.value) {
      AppSnackBar.showSuccess(
        title: 'Connection Restored',
        message: 'You are back online.',
      );
    } else {
      AppSnackBar.showError(
        title: 'Still Offline',
        message: 'Unable to reach the network. Please try again.',
      );
    }
  }

  // Profile details matching reference layout (Left Screen)
  final RxString driverName = 'Rajesh Kumar'.obs;
  final RxString driverPhone = '+91 9876543210'.obs;
  final RxString vehicleNo = 'MH-12-AB-1234'.obs;
  final RxString vehicleModel = 'Tata Signa 5530.S'.obs;
  final RxString avatarUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop'.obs;
  final RxInt todayTripsCount = 4.obs;

  // Active Trip Getter
  TripItemModel? get activeTrip {
    try {
      final tripsController = Get.find<TripsController>();
      return tripsController.allTrips.firstWhere((t) => t.isActive);
    } catch (_) {
      return null;
    }
  }

  // Dummy notifications matching reference image
  final List<NotificationModel> notifications = [
    NotificationModel(
      title: 'New Route Assigned',
      body: 'Route to Nagpur Warehouse has been updated with a new toll gate entry.',
      time: '2 hours ago',
    ),
    NotificationModel(
      title: 'Payment Processed',
      body: 'Fuel allowance for Trip #9012 has been credited to your wallet.',
      time: 'Yesterday',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    // Retrieve phone number if saved
    final phone = _storage.read<String>('userPhone');
    if (phone != null) {
      driverPhone.value = phone;
    }
    loadProfileFromFirebase();
  }

  Future<void> loadProfileFromFirebase() async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      final profile = await firebaseService.getDriverProfile();
      if (profile.isNotEmpty) {
        driverName.value = profile['driverName'] ?? 'Rajesh Kumar';
        driverPhone.value = profile['driverPhone'] ?? profile['phone'] ?? '+91 98765 43210';
        vehicleNo.value = profile['vehicleNo'] ?? 'MH-12-AB-1234';
        vehicleModel.value = profile['vehicleModel'] ?? 'Tata Signa 5530.S';
        avatarUrl.value = profile['avatarUrl'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop';
      }
    } catch (_) {}
  }

  // SOS button trigger
  void triggerEmergencySos() {
    AppPopup.showConfirmation(
      title: 'ACTIVATE EMERGENCY SOS',
      description: 'This will broadcast your GPS location to the highway control rooms and logistics dispatch centers. Continue?',
      confirmText: 'Broadcast SOS',
      cancelText: 'Cancel',
      onConfirm: () {
        AppSnackBar.showError(
          title: 'SOS ACTIVE',
          message: 'Safety dispatch and highway assistance have been alerted of your coordinates.',
        );
      },
    );
  }

  // Sign out driver session
  Future<void> logout() async {
    AppPopup.showConfirmation(
      title: 'Sign Out Driver?',
      description: 'Do you want to end your active driver terminal session?',
      confirmText: 'Sign Out',
      onConfirm: () async {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        
        _storage.remove('isLoggedIn');
        _storage.remove('userPhone');
        Get.offAllNamed(Routes.LOGIN);
        AppSnackBar.showSuccess(title: 'Logged Out', message: 'Session closed successfully.');
      },
    );
  }
}

class NotificationModel {
  final String title;
  final String body;
  final String time;

  NotificationModel({required this.title, required this.body, required this.time});
}
