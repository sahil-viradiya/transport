import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/session_service.dart';

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

  // Filtered trips list getter
  List<TripItemModel> get filteredTrips {
    return allTrips.where((trip) {
      final matchesTab = trip.tabType == activeTab.value;
      final matchesSearch = searchQuery.value.isEmpty ||
          trip.id.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.truckNo.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.pickupCity.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          trip.dropCity.toLowerCase().contains(searchQuery.value.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();
  }

  void selectTab(String tab) {
    activeTab.value = tab;
  }

  @override
  void onInit() {
    super.onInit();
    fetchTripsFromFirebase();
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

  @override
  void onClose() {
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
  final int currentMilestone;
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
    this.currentMilestone = 0,
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


