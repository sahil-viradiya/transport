import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/session_service.dart';
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

  // Filtered trips list getter — priority (PENDING) trips float to the top.
  List<TripItemModel> get filteredTrips {
    final list = allTrips.where((trip) {
      final matchesTab = trip.tabType == activeTab.value;
      final matchesSearch = searchQuery.value.isEmpty ||
          trip.id.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.truckNo.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.pickupCity.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.dropCity.toLowerCase().contains(searchQuery.value.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();
    list.sort((a, b) {
      // Priority first, then still-pending (needs action) above the rest.
      if (a.priority != b.priority) return a.priority ? -1 : 1;
      final aPending = a.status == 'PENDING' ? 0 : 1;
      final bPending = b.status == 'PENDING' ? 0 : 1;
      return aPending.compareTo(bPending);
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
  });
}


