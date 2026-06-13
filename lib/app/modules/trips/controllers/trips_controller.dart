import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TripsController extends GetxController {
  final searchController = TextEditingController();
  final RxString activeTab = 'Today'.obs;
  final RxString searchQuery = ''.obs;

  // Static stats
  final int pendingPickups = 4;
  final int weeklyTrips = 12;

  // List of trips matching reference layout (Right Screen)
  final RxList<TripItemModel> allTrips = <TripItemModel>[
    TripItemModel(
      id: 'TRP-9021-X',
      truckNo: 'MH-12-BV-0045',
      status: 'ACTIVE NOW',
      pickupCity: 'Mumbai',
      pickupLocation: 'JNPT Terminal',
      dropCity: 'Nagpur',
      dropLocation: 'Mihan Hub',
      date: '24 Oct, 08:30 AM',
      tabType: 'Today',
      isActive: true,
    ),
    TripItemModel(
      id: 'TRP-8842-B',
      truckNo: 'HR-55-AN-9912',
      status: 'ASSIGNED',
      pickupCity: 'Pune',
      pickupLocation: 'Chakan Plant',
      dropCity: 'Mumbai',
      dropLocation: 'Customs Gate 4',
      date: '24 Oct, 02:00 PM',
      tabType: 'Today',
      isActive: false,
    ),
    TripItemModel(
      id: 'TRP-7761-Z',
      truckNo: 'MH-04-ET-1188',
      status: 'ASSIGNED',
      pickupCity: 'Nashik',
      pickupLocation: 'Industrial Area',
      dropCity: 'Ahmedabad',
      dropLocation: 'Transport Nagar',
      date: '25 Oct, 06:00 AM',
      tabType: 'Upcoming',
      isActive: false,
    ),
  ].obs;

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
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
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
  });
}
