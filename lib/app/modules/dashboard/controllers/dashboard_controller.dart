import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/data/services/connectivity_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/location_service.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:geolocator/geolocator.dart';
import '../views/widgets/parking_confirmation_dialog.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../inspection/views/inspection_view.dart';


class DashboardController extends GetxController {
  final _session = Get.find<SessionService>();
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

  // Duty / check-in state
  final RxString dutyStatus = 'off_duty'.obs; // 'available' | 'off_duty'
  final RxString checkInAddress = ''.obs;
  final RxBool isCheckingDuty = false.obs;
  bool get isOnDuty => dutyStatus.value == 'available';

  // Assigned truck + daily inspection state (live from Firestore)
  final Rxn<Map<String, dynamic>> myTruck = Rxn<Map<String, dynamic>>();
  StreamSubscription? _truckSub;
  StreamSubscription? _userSub;
  String get myTruckNo => (myTruck.value?['truckNo'] ?? '').toString();
  String get truckInspection {
    final status = (myTruck.value?['inspectionStatus'] ?? '').toString();
    if (status == 'inspected_pending_review' ||
        status == 'approved_pending_accept') {
      return 'ready';
    }
    return status;
  }

  // Active Trip Getter
  TripItemModel? get activeTrip {
    try {
      final tripsController = Get.find<TripsController>();
      return tripsController.allTrips.firstWhere((t) => t.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Today's running trip: the active one, else the first not-yet-completed
  /// trip (drives the dashboard "Today's Trip" tile + progress card).
  TripItemModel? get currentTrip {
    try {
      final tc = Get.find<TripsController>();
      return activeTrip ??
          tc.allTrips.firstWhereOrNull(
              (t) => t.status != 'DELIVERED' && t.status != 'REJECTED');
    } catch (_) {
      return null;
    }
  }

  /// Truck-inspection checklist submit (reference form). Sets state to pending review.
  Future<bool> submitInspection({
    required Map<String, bool> results, // item -> isGood
    required String remarks,
    required List<Uint8List> images,
  }) async {
    final truckNo = myTruckNo;
    if (truckNo.isEmpty) return false;
    AppPopup.showLoading(message: 'Submitting inspection...');
    try {
      final fb = Get.find<FirebaseService>();
      final List<String> imageUrls = [];
      if (images.isNotEmpty) {
        final url = await fb.uploadTruckIssueImage(truckNo, images.first);
        if (url.isNotEmpty) imageUrls.add(url);
      }
      await fb.submitTruckInspection(
        truckNo,
        results: results,
        remarks: remarks,
        imageUrls: imageUrls,
        driverName: driverName.value,
      );
      AppPopup.hideLoading();
      return true;
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
      return false;
    }
  }

  /// Driver accepts the truck after inspection approval.
  Future<void> acceptMyTruck() async {
    final truckNo = myTruckNo;
    if (truckNo.isEmpty) return;
    AppPopup.showLoading(message: 'Accepting truck...');
    try {
      final fb = Get.find<FirebaseService>();
      await fb.acceptTruck(truckNo, driverName: driverName.value);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
        title: 'Truck Accepted 🚛',
        message: 'Aapne truck $truckNo accept kar liya hai.',
      );
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
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
    // Seed initial values from the live session
    if (_session.phone.value.isNotEmpty) {
      driverPhone.value = _session.phone.value;
    }
    if (_session.name.value.isNotEmpty) {
      driverName.value = _session.name.value;
    }
    if (_session.avatarUrl.value.isNotEmpty) {
      avatarUrl.value = _session.avatarUrl.value;
    }
    loadProfileFromFirebase();

    // Live: the truck assigned to this driver (morning duty allocation).
    try {
      final fb = Get.find<FirebaseService>();
      _truckSub = fb
          .watchTruckForDriver(_session.ownerKey)
          .listen(myTruck.call);

      _userSub = fb.watchUserData(_session.ownerKey).listen((data) {
        if (data.isNotEmpty) {
          driverName.value = data['name'] ?? driverName.value;
          driverPhone.value = data['phone'] ?? _session.ownerKey;
          final url = data['avatarUrl'] ?? '';
          if (url.toString().isNotEmpty) avatarUrl.value = url;
          final isAvail = (data['availability'] == 'available') ||
              (data['checkedIn'] == true);
          dutyStatus.value = data['dutyStatus'] ?? (isAvail ? 'available' : 'off_duty');
          returnJourneyStatus.value = data['returnJourneyStatus'] ?? 'none';
          canClockOut.value = data['canClockOut'] == true;
          if (data['parkingConfirmation'] is Map) {
            parkingConfirmation.value = Map<String, dynamic>.from(data['parkingConfirmation']);
          }
          checkInAddress.value = data['checkInAddress'] ?? '';
        }
      });
    } catch (_) {}

    // Listen to allTrips in TripsController to reactively refresh profile statistics
    try {
      final tripsController = Get.find<TripsController>();
      ever(tripsController.allTrips, (_) {
        loadProfileFromFirebase();
      });
    } catch (_) {}
  }

  final RxString returnJourneyStatus = 'none'.obs; // 'none' | 'in_transit' | 'parking_requested' | 'verified' | 'rejected'
  final Rxn<Map<String, dynamic>> parkingConfirmation = Rxn<Map<String, dynamic>>();
  final RxBool canClockOut = false.obs;

  bool get hasCompletedAllTrips {
    try {
      if (!Get.isRegistered<TripsController>()) return false;
      final tc = Get.find<TripsController>();
      if (tc.allTrips.isEmpty) return false;
      return tc.allTrips.every((t) => t.status == 'DELIVERED' || t.status == 'REJECTED');
    } catch (_) {
      return false;
    }
  }

  Future<void> startReturnJourney() async {
    AppPopup.showConfirmation(
      title: 'Return to Transport Station?',
      description: 'Finished all trips? Confirm to start your return journey back to the station.',
      confirmText: 'Start Return',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Updating status...');
        try {
          final fb = Get.find<FirebaseService>();
          await fb.startReturnJourney(
            key: _session.ownerKey,
            driverName: driverName.value,
          );
          returnJourneyStatus.value = 'in_transit';
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
            title: 'Journey Started 🚛',
            message: 'Your status is set to Returning to Station. Admin has been notified.',
          );
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  Future<void> openParkingConfirmationDialog(BuildContext context) async {
    AppPopup.showLoading(message: 'Capturing live GPS location...');
    try {
      final loc = Get.find<LocationService>();
      final pos = await loc.getCurrentPosition();
      final address = await loc.getAddressFromCoordinates(pos.latitude, pos.longitude);
      
      final distanceMeters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        LocationService.fallbackLatitude,
        LocationService.fallbackLongitude,
      );
      final distanceKm = distanceMeters / 1000.0;

      AppPopup.hideLoading();

      await ParkingConfirmationDialog.show(
        context: context,
        driverName: driverName.value,
        driverId: _session.ownerKey,
        vehicleNo: vehicleNo.value.isNotEmpty ? vehicleNo.value : (myTruckNo.isNotEmpty ? myTruckNo : 'GJ-01-AX-9988'),
        address: address,
        distanceKm: distanceKm,
        onSubmit: (bytes) async {
          await _submitParkingConfirmation(
            photoBytes: bytes,
            latitude: pos.latitude,
            longitude: pos.longitude,
            address: address,
            distanceKm: distanceKm,
          );
        },
      );
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'GPS Error', message: 'Could not fetch location: $e');
    }
  }

  Future<void> _submitParkingConfirmation({
    required Uint8List photoBytes,
    required double latitude,
    required double longitude,
    required String address,
    required double distanceKm,
  }) async {
    AppPopup.showLoading(message: 'Submitting parking request...');
    try {
      final fb = Get.find<FirebaseService>();
      final vNo = vehicleNo.value.isNotEmpty ? vehicleNo.value : (myTruckNo.isNotEmpty ? myTruckNo : 'GJ-01-AX-9988');
      await fb.submitParkingConfirmation(
        driverId: _session.ownerKey,
        driverName: driverName.value,
        vehicleNo: vNo,
        photoBytes: photoBytes,
        latitude: latitude,
        longitude: longitude,
        address: address,
        distanceKm: distanceKm,
      );
      returnJourneyStatus.value = 'parking_requested';
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
        title: 'Parking Request Submitted 🅿️',
        message: 'Admin notification sent. Waiting for station verification.',
      );
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
      rethrow;
    }
  }


  @override
  void onClose() {
    _userSub?.cancel();
    _truckSub?.cancel();
    super.onClose();
  }

  Future<void> confirmTruckAssignment(bool accept, {String rejectReason = '', String rejectImageUrl = ''}) async {
    final truckNo = myTruckNo;
    if (truckNo.isEmpty) return;
    AppPopup.showLoading(message: accept ? 'Accepting truck...' : 'Rejecting truck...');
    try {
      if (accept) {
        await Get.find<FirebaseService>().acceptTruckAssignment(truckNo, _session.phone.value);
        AppPopup.hideLoading();
        Get.to(() => const TruckInspectionFormView());
      } else {
        await Get.find<FirebaseService>().reportTruckIssue(
          truckNo,
          reason: rejectReason,
          imageUrl: rejectImageUrl,
          driverName: driverName.value,
        );
        AppPopup.hideLoading();
        AppSnackBar.showSuccess(title: 'Rejected', message: 'Truck assignment rejected. Admin ko notify kar diya.');
      }
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  /// Driver confirms the assigned truck's condition is proper → READY.
  void acceptAssignedTruck() {
    final truckNo = myTruckNo;
    if (truckNo.isEmpty) return;
    AppPopup.showConfirmation(
      title: 'Accept Truck?',
      description:
          'Aapne truck $truckNo ka inspection kar liya aur condition proper '
          'hai? Admin ko inform kiya jayega.',
      confirmText: 'Accept',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Accepting truck...');
        try {
          await Get.find<FirebaseService>()
              .acceptTruck(truckNo, driverName: driverName.value);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
              title: 'Truck Ready ✅',
              message: '$truckNo trip ke liye ready hai. Admin ko bata diya.');
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  /// Driver found a problem during inspection → reason + photo → admin.
  void reportTruckProblem() {
    final truckNo = myTruckNo;
    if (truckNo.isEmpty) return;
    final reasonCtrl = TextEditingController();
    final photoBytes = Rx<Uint8List?>(null);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Problem in $truckNo?',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Problem kya hai? (e.g. tyre puncture)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => photoBytes.value == null
                ? OutlinedButton.icon(
                    onPressed: () async {
                      final x = await ImagePicker().pickImage(
                          source: ImageSource.camera, imageQuality: 70);
                      if (x != null) photoBytes.value = await x.readAsBytes();
                    },
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Attach Photo'),
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(photoBytes.value!,
                            width: 48, height: 48, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('Photo attached ✓',
                              style: TextStyle(color: Color(0xFF16A34A)))),
                      TextButton(
                        onPressed: () => photoBytes.value = null,
                        child: const Text('Change'),
                      ),
                    ],
                  )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                AppSnackBar.showWarning(
                    title: 'Reason Required',
                    message: 'Problem ka reason likhna zaroori hai.');
                return;
              }
              Get.back();
              AppPopup.showLoading(message: 'Reporting problem...');
              try {
                final fb = Get.find<FirebaseService>();
                String imageUrl = '';
                if (photoBytes.value != null) {
                  imageUrl =
                      await fb.uploadTruckIssueImage(truckNo, photoBytes.value);
                }
                await fb.reportTruckIssue(
                  truckNo,
                  reason: reason,
                  imageUrl: imageUrl,
                  driverName: driverName.value,
                );
                AppPopup.hideLoading();
                AppSnackBar.showInfo(
                    title: 'Problem Reported ⚠️',
                    message: 'Admin ko bata diya gaya hai.');
              } catch (e) {
                AppPopup.hideLoading();
                AppSnackBar.showError(title: 'Error', message: e.toString());
              }
            },
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> loadProfileFromFirebase() async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      final phone = _session.ownerKey;
      if (phone.isEmpty) return;

      // 1. Fetch profile details (users directory + owner profile doc)
      final userData = await firebaseService.getUserData(phone);
      if (userData != null) {
        driverName.value = userData['name'] ?? driverName.value;
        driverPhone.value = userData['phone'] ?? phone;
        final url = userData['avatarUrl'] ?? '';
        if (url.toString().isNotEmpty) avatarUrl.value = url;
        final isAvail = (userData['availability'] == 'available') ||
            (userData['checkedIn'] == true);
        dutyStatus.value = isAvail ? 'available' : 'off_duty';
        checkInAddress.value = userData['checkInAddress'] ?? '';
      }

      // 2. Owner-scoped trips: count + active/latest truck number
      final driverTrips = await firebaseService.getTripsForOwner(phone);

      todayTripsCount.value = driverTrips.length;

      final activeOrLatestTrip = driverTrips.firstWhere(
        (t) => t.isActive,
        orElse: () => driverTrips.isNotEmpty ? driverTrips.first : TripItemModel(
          id: '',
          truckNo: '',
          status: '',
          pickupCity: '',
          pickupLocation: '',
          dropCity: '',
          dropLocation: '',
          date: '',
          tabType: '',
          isActive: false,
        ),
      );

      if (activeOrLatestTrip.id.isNotEmpty) {
        final truckNoVal = activeOrLatestTrip.truckNo;
        vehicleNo.value = truckNoVal;

        // Lookup truck details (owner-scoped) to get truck model info
        final allTrucks = await firebaseService.getTrucksForOwner(_session.ownerKey);
        final truck = allTrucks.firstWhere(
          (t) => t['truckNo'] == truckNoVal,
          orElse: () => <String, dynamic>{},
        );
        if (truck.isNotEmpty) {
          vehicleModel.value = truck['model'] ?? 'Tata Signa 5530.S';
        } else {
          vehicleModel.value = 'N/A';
        }
      } else {
        vehicleNo.value = 'No Truck Assigned';
        vehicleModel.value = 'N/A';
      }
    } catch (_) {}
  }

  /// Ensures the driver is checked in (Go On Duty) before performing any app activity.
  /// If the driver is Off Duty, displays a forceful dialog requiring check-in.
  bool ensureCheckedIn() {
    if (!isOnDuty) {
      AppPopup.showConfirmation(
        title: 'Check-In Required 🔴',
        description:
            'Aap abhi Off Duty hain. Koi bhi activity perform karne ke liye pehle Check-In (Go On Duty) karna zaroori hai.',
        confirmText: 'Check In Now 🟢',
        onConfirm: () {
          checkIn();
        },
      );
      return false;
    }
    return true;
  }

  /// Driver goes on duty: capture GPS, mark Available, notify admin.
  Future<void> checkIn() async {
    if (isCheckingDuty.value) return;
    isCheckingDuty.value = true;
    AppPopup.showLoading(message: 'Checking in — capturing location...');
    try {
      final location = Get.find<LocationService>();
      final fb = Get.find<FirebaseService>();
      final pos = await location.getCurrentPosition();
      final address =
          await location.getAddressFromCoordinates(pos.latitude, pos.longitude);
      await fb.checkIn(
        _session.ownerKey,
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: address,
        driverName: driverName.value,
      );
      dutyStatus.value = 'available';
      checkInAddress.value = address;
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
        title: 'Checked In ✅',
        message: 'You are now Available.\n$address',
      );
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(
          title: 'Check-In Failed', message: 'Could not check in. Try again.');
    } finally {
      isCheckingDuty.value = false;
    }
  }

  /// Driver goes off duty.
  void checkOut() {
    if ((hasCompletedAllTrips || returnJourneyStatus.value != 'none') &&
        dutyStatus.value != 'STATION_VERIFIED' &&
        !canClockOut.value) {
      AppSnackBar.showWarning(
        title: 'Clock Out Locked 🔒',
        message: 'Parking verification required from admin before clocking out.',
      );
      return;
    }

    AppPopup.showConfirmation(
      title: 'Clock Out / End Shift?',

      description: 'Are you sure you want to clock out? You will need to clock in again to resume driver activities.',
      confirmText: 'Clock Out',
      onConfirm: () async {
        isCheckingDuty.value = true;
        AppPopup.showLoading(message: 'Clocking out...');
        try {
          final fb = Get.find<FirebaseService>();
          await fb.checkOut(_session.ownerKey, driverName: driverName.value);
          if (Get.isRegistered<ClockInService>()) {
            await Get.find<ClockInService>().clockOut();
          }
          dutyStatus.value = 'off_duty';
          AppPopup.hideLoading();
          AppSnackBar.showInfo(
              title: 'Checked Out', message: 'You are now Off Duty.');
          Get.offAllNamed(Routes.CLOCK_IN);
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        } finally {
          isCheckingDuty.value = false;
        }
      },
    );
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
        await Get.find<AuthService>().signOut();
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
