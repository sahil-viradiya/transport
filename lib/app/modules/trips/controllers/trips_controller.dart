import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/session_service.dart';
import '../../../data/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../widgets/dialogs/app_popup.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';

class TripsController extends GetxController {
  final searchController = TextEditingController();
  final RxString activeTab = 'Today'.obs;
  final RxString searchQuery = ''.obs;

  // Static stats
  final int pendingPickups = 4;
  final int weeklyTrips = 12;

  final RxBool isLoading = false.obs;

  // Live owner-scoped trips, populated from Firestore in [fetchTripsFromFirebase].
  final RxList<TripItemModel> allTrips = <TripItemModel>[].obs;

  static const _ongoingStatuses = {
    'EN_ROUTE_VENDOR',
    'LOADING',
    'LOAD_REQUESTED',
    'ACTIVE NOW',
    'DELIVERY_REQUESTED',
  };

  bool _matchesTab(TripItemModel trip) {
    switch (activeTab.value) {
      case 'Today':
        final todayStr = DateTime.now().toString().split(' ')[0];
        final isToday = trip.date == todayStr;
        final isCurrent = trip.status != 'DELIVERED' && trip.status != 'REJECTED';
        return isToday || isCurrent;
      case 'Upcoming':
        return trip.status == 'PENDING' || trip.status == 'ASSIGNED';
      case 'Ongoing':
        return _ongoingStatuses.contains(trip.status);
      case 'Completed':
        return trip.status == 'DELIVERED' || trip.status == 'REJECTED';
      default: // All
        return true;
    }
  }

  int _statusSortWeight(String status) {
    switch (status) {
      case 'ACTIVE NOW':
      case 'DELIVERY_REQUESTED':
      case 'EN_ROUTE_VENDOR':
      case 'LOADING':
      case 'LOAD_REQUESTED':
        return 0; // Active / Ongoing
      case 'PENDING':
      case 'ASSIGNED':
        return 1; // Scheduled / Upcoming
      case 'DELIVERED':
      case 'REJECTED':
        return 2; // Completed / Rejected
      default:
        return 3;
    }
  }

  // Filtered trips list getter — active/ongoing first, then scheduled/upcoming, then completed.
  List<TripItemModel> get filteredTrips {
    final list = allTrips.where((trip) {
      final matchesSearch = searchQuery.value.isEmpty ||
          trip.id.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.truckNo.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.pickupCity.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.dropCity.toLowerCase().contains(searchQuery.value.toLowerCase());
      return _matchesTab(trip) && matchesSearch;
    }).toList();
    list.sort((a, b) {
      final weightA = _statusSortWeight(a.status);
      final weightB = _statusSortWeight(b.status);
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      if (a.priority != b.priority) {
        return a.priority ? -1 : 1;
      }
      return 0;
    });
    return list;
  }

  /// True when the driver has a priority trip still waiting to be accepted.
  bool get hasPendingPriority =>
      allTrips.any((t) => t.priority && t.status == 'PENDING');

  void selectTab(String tab) {
    activeTab.value = tab;
  }

  StreamSubscription? _tripsSub;

  @override
  void onInit() {
    super.onInit();
    // Live stream: the driver's trip list stays current the moment anything
    // changes in Firestore (admin assigns, approves load/delivery, etc.) — no
    // manual refresh needed when moving between screens.
    try {
      final firebaseService = Get.find<FirebaseService>();
      final session = Get.find<SessionService>();
      _tripsSub = firebaseService
          .watchTripsForOwner(session.ownerKey)
          .listen(allTrips.assignAll);
    } catch (_) {
      fetchTripsFromFirebase();
    }
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  Future<void> fetchTripsFromFirebase() async {
    isLoading.value = true;
    try {
      final firebaseService = Get.find<FirebaseService>();
      final session = Get.find<SessionService>();
      final list = await firebaseService.getTripsForOwner(session.ownerKey);
      allTrips.assignAll(list);
    } catch (_) {}
    isLoading.value = false;
  }

  /// Driver confirms a PENDING trip. Only after this does it become ready to
  /// start; the admin who assigned it gets notified.
  Future<void> acceptTrip(String tripId) async {
    final fb = Get.find<FirebaseService>();
    final session = Get.find<SessionService>();
    AppPopup.showLoading(message: 'Confirming trip...');
    try {
      await fb.acceptTrip(tripId, driverName: session.name.value);
      await fetchTripsFromFirebase();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Trip Confirmed',
          message: 'You accepted trip $tripId. You can start it now.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  /// Driver rejects a PENDING trip with an optional reason; admin is notified.
  Future<void> rejectTrip(String tripId, String reason) async {
    final fb = Get.find<FirebaseService>();
    final session = Get.find<SessionService>();
    AppPopup.showLoading(message: 'Rejecting trip...');
    try {
      await fb.rejectTrip(tripId, reason: reason, driverName: session.name.value);
      await fetchTripsFromFirebase();
      AppPopup.hideLoading();
      AppSnackBar.showInfo(
          title: 'Trip Rejected',
          message: 'Trip $tripId rejected. Admin has been informed.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  void confirmRejectTrip(String tripId) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Trip?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aap ye trip reject karna chahte hain? '
                'Reason likhein (optional).'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (e.g. truck busy)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Get.back();
              rejectTrip(tripId, reasonCtrl.text.trim());
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Driver starts the trip — heads to vendor (ASSIGNED → EN_ROUTE_VENDOR)
  Future<void> startTrip(String tripId) async {
    final fb = Get.find<FirebaseService>();
    final session = Get.find<SessionService>();
    final locationService = Get.find<LocationService>();
    AppPopup.showLoading(message: 'Starting trip...');
    try {
      await locationService.checkLocationAccess();
      final pos = await locationService.getCurrentPosition();
      final address = await locationService.getAddressFromCoordinates(pos.latitude, pos.longitude);

      await fb.startToVendor(
        tripId,
        location: address,
        latitude: pos.latitude,
        longitude: pos.longitude,
        driverName: session.name.value,
      );
      await fetchTripsFromFirebase();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Trip Started',
          message: 'Aap vendor ke liye nikal rahe ho. Safe driving!');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  /// Driver reached the loading point (EN_ROUTE_VENDOR → LOADING)
  Future<void> markReachedLoading(String tripId) async {
    final fb = Get.find<FirebaseService>();
    final session = Get.find<SessionService>();
    final locationService = Get.find<LocationService>();
    AppPopup.showLoading(message: 'Marking reached...');
    try {
      await locationService.checkLocationAccess();
      final pos = await locationService.getCurrentPosition();
      final address = await locationService.getAddressFromCoordinates(pos.latitude, pos.longitude);

      await fb.startLoading(
        tripId,
        location: address,
        latitude: pos.latitude,
        longitude: pos.longitude,
        driverName: session.name.value,
      );
      await fetchTripsFromFirebase();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Reached Loading Point',
          message: 'Loading point par pahunch gaye. Truck loaded hone par photo upload karein.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  /// Driver uploads loading photo and requests admin approval (LOADING → LOAD_REQUESTED)
  Future<void> markTruckLoaded(String tripId, Uint8List photoBytes, Uint8List gatePassBytes) async {
    final fb = Get.find<FirebaseService>();
    final session = Get.find<SessionService>();
    final locationService = Get.find<LocationService>();
    AppPopup.showLoading(message: 'Uploading photos & requesting approval...');
    try {
      await locationService.checkLocationAccess();
      final pos = await locationService.getCurrentPosition();
      final address = await locationService.getAddressFromCoordinates(pos.latitude, pos.longitude);

      final photoUrl = await fb.uploadLoadingPhoto(tripId, photoBytes);
      final gatePassUrl = await fb.uploadGatePassPhoto(tripId, gatePassBytes);
      await fb.requestLoadApproval(
        tripId,
        pickupLocation: address,
        latitude: pos.latitude,
        longitude: pos.longitude,
        driverName: session.name.value,
        loadingPhotoUrl: photoUrl,
        gatePassPhotoUrl: gatePassUrl,
      );
      await fetchTripsFromFirebase();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Load Submitted',
          message: 'Admin ko photos bhej di gayi hain. Approval ka wait karein.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  @override
  void onClose() {
    _tripsSub?.cancel();
    searchController.dispose();
    super.onClose();
  }
}

class TripItemModel {
  final String id;
  final String truckNo;
  final String status;
  final String pickupCity;
  final String pickupLocation;
  final String dropCity;
  final String dropLocation;
  final String date;
  final String tabType;
  final bool isActive;
  final bool priority;
  final int currentMilestone;
  // Vendor / material details (morning assignment form)
  final String vendorName;
  final String vendorLocation;
  final String materialName;
  final String productName;
  final String passHolderName;
  final String royaltyName;
  final String loadingPassId;
  final String minPassId;
  final String maxPassId;
  final String pickupDistrict;
  final String remainingDistance;
  final String estimatedTime;
  final String currentAddress;
  final String driverPhone;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropLatitude;
  final double? dropLongitude;
  final List<dynamic>? milestonesLog;
  final String? podUrl;
  final String? remarks;
  final String? loadingPhotoUrl;
  final String? gatePassPhotoUrl;

  TripItemModel({
    required this.id,
    required this.truckNo,
    required this.status,
    required this.pickupCity,
    required this.pickupLocation,
    required this.dropCity,
    required this.dropLocation,
    required this.date,
    required this.tabType,
    required this.isActive,
    this.priority = false,
    this.currentMilestone = 0,
    this.vendorName = '',
    this.vendorLocation = '',
    this.materialName = '',
    this.productName = '',
    this.passHolderName = '',
    this.royaltyName = '',
    this.loadingPassId = '',
    this.minPassId = '',
    this.maxPassId = '',
    this.pickupDistrict = '',
    this.remainingDistance = '',
    this.estimatedTime = '',
    this.currentAddress = '',
    this.driverPhone = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropLatitude,
    this.dropLongitude,
    this.milestonesLog,
    this.podUrl,
    this.remarks,
    this.loadingPhotoUrl,
    this.gatePassPhotoUrl,
  });
}


