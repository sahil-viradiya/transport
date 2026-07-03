import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';

class AdminHomeController extends GetxController {
  final _firebaseService = Get.find<FirebaseService>();
  final _storage = Get.find<StorageService>();

  final RxInt currentTabIndex = 0.obs;
  final RxBool isLoading = false.obs;

  // Database lists
  final RxList<Map<String, dynamic>> trips = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> trucks = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;

  StreamSubscription? _tripsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _usersSub;

  @override
  void onInit() {
    super.onInit();
    loadData();
    _startLiveUpdates();
  }

  @override
  void onClose() {
    _tripsSub?.cancel();
    _expensesSub?.cancel();
    _usersSub?.cancel();
    super.onClose();
  }

  // Live admin dashboard: trips + expenses + users (driver availability) stay
  // current — no manual refresh needed.
  void _startLiveUpdates() {
    _tripsSub = _firebaseService.watchAllTrips().listen((list) {
      trips.assignAll(list.map(_mapTrip).toList());
    });
    _expensesSub = _firebaseService.watchAllExpenses().listen((list) {
      expenses.assignAll(list);
    });
    _usersSub = _firebaseService.watchAllUsers().listen(users.assignAll);
  }

  Map<String, dynamic> _mapTrip(dynamic trip) => {
        'id': trip.id,
        'truckNo': trip.truckNo,
        'driverPhone': trip.driverPhone,
        'status': trip.status,
        'pickupCity': trip.pickupCity,
        'pickupLocation': trip.pickupLocation,
        'dropCity': trip.dropCity,
        'dropLocation': trip.dropLocation,
        'date': trip.date,
        'isActive': trip.isActive,
        'priority': trip.priority,
        'currentMilestone': trip.currentMilestone,
        'tabType': trip.tabType,
        'remainingDistance': trip.remainingDistance,
        'estimatedTime': trip.estimatedTime,
        'currentAddress': trip.currentAddress,
        'pickupLatitude': trip.pickupLatitude,
        'pickupLongitude': trip.pickupLongitude,
        'dropLatitude': trip.dropLatitude,
        'dropLongitude': trip.dropLongitude,
        'milestonesLog': trip.milestonesLog,
        'podUrl': trip.podUrl,
        'remarks': trip.remarks,
      };

  void changeTabIndex(int index) {
    currentTabIndex.value = index;
  }

  // Load all admin collections from Firestore
  Future<void> loadData() async {
    isLoading.value = true;
    try {
      // Fetch users
      final fetchedUsers = await _firebaseService.getUsers();
      users.assignAll(fetchedUsers);

      // Fetch trucks
      final fetchedTrucks = await _firebaseService.getTrucks();
      trucks.assignAll(fetchedTrucks);

      // Fetch expenses
      final fetchedExpenses = await _firebaseService.getExpenses();
      expenses.assignAll(fetchedExpenses);

      // Fetch trips
      final fetchedTrips = await _firebaseService.getTrips();
      trips.assignAll(fetchedTrips.map(_mapTrip).toList());
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // On-demand: pull the latest saved position for a trip (the driver app saves
  // it roughly every 10 minutes while the trip is active). This is a fresh read,
  // not a live subscription, so the admin gets the truck's last-known location
  // only when they ask for it.
  Future<Map<String, dynamic>?> fetchTripLocation(String tripId) async {
    return _firebaseService.getTripData(tripId);
  }

  // --- TRIP CRUD ACTIONS ---
  Future<void> createTrip(Map<String, dynamic> tripData) async {
    final tripId = tripData['id'] as String;
    AppPopup.showLoading(message: 'Assigning Trip $tripId...');
    try {
      // Assign as PENDING and notify the driver to accept/reject — the trip only
      // becomes active after the driver confirms.
      await _firebaseService.assignTripToDriver(tripId, tripData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Trip Assigned',
          message: 'Trip $tripId sent to the driver for confirmation.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> editTrip(String tripId, Map<String, dynamic> tripData) async {
    AppPopup.showLoading(message: 'Updating Trip...');
    try {
      await _firebaseService.saveTrip(tripId, tripData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'Trip Updated', message: 'Trip details modified.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteTrip(String tripId) async {
    AppPopup.showConfirmation(
      title: 'Delete Trip?',
      description: 'Are you sure you want to permanently delete Trip $tripId?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting Trip...');
        try {
          await _firebaseService.deleteTrip(tripId);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(title: 'Deleted', message: 'Trip removed from database.');
          await loadData();
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  // --- TRUCK CRUD ACTIONS ---
  Future<void> createTruck(Map<String, dynamic> truckData) async {
    final truckNo = truckData['truckNo'] as String;
    AppPopup.showLoading(message: 'Registering Truck $truckNo...');
    try {
      await _firebaseService.saveTruck(truckNo, truckData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'Truck Registered', message: 'Truck added successfully.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> editTruck(String truckNo, Map<String, dynamic> truckData) async {
    AppPopup.showLoading(message: 'Updating Truck...');
    try {
      await _firebaseService.saveTruck(truckNo, truckData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'Truck Updated', message: 'Truck profile updated.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteTruck(String truckNo) async {
    AppPopup.showConfirmation(
      title: 'Delete Truck?',
      description: 'Are you sure you want to permanently delete Truck $truckNo?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting Truck...');
        try {
          await _firebaseService.deleteTruck(truckNo);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(title: 'Deleted', message: 'Truck removed from database.');
          await loadData();
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  // --- ROLE & USER ACTIONS ---
  Future<void> createUser(Map<String, dynamic> userData) async {
    final phone = userData['phone'] as String;
    AppPopup.showLoading(message: 'Creating User profile...');
    try {
      await _firebaseService.saveUser(phone, userData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'User Added', message: 'User profile registered.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> editUserRole(String phone, String newRole) async {
    AppPopup.showLoading(message: 'Updating user role...');
    try {
      await _firebaseService.updateUserRole(phone, newRole);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'Role Updated', message: 'Role set to: $newRole');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteUser(String phone) async {
    AppPopup.showConfirmation(
      title: 'Delete User?',
      description: 'Are you sure you want to permanently delete profile for $phone?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting profile...');
        try {
          await _firebaseService.deleteUser(phone);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(title: 'Deleted', message: 'User profile removed.');
          await loadData();
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  // --- EXPENSE ACTIONS ---
  Future<void> approveExpense(Map<String, dynamic> expenseData) async {
    final id = expenseData['id']?.toString() ?? '';
    if (id.isEmpty) return;
    AppPopup.showLoading(message: 'Approving expense...');
    try {
      await _firebaseService.approveExpenseById(id);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Expense Approved', message: 'The driver has been notified.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> rejectExpense(Map<String, dynamic> expenseData) async {
    final id = expenseData['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final reasonCtrl = TextEditingController();
    AppPopup.showConfirmation(
      title: 'Reject Expense?',
      description: 'This claim will be marked rejected and the driver notified.',
      confirmText: 'Reject',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Rejecting...');
        try {
          await _firebaseService.rejectExpenseById(id,
              reason: reasonCtrl.text.trim());
          AppPopup.hideLoading();
          AppSnackBar.showInfo(
              title: 'Expense Rejected', message: 'The driver has been notified.');
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  // --- LOGOUT TERMINAL ---
  Future<void> logout() async {
    AppPopup.showConfirmation(
      title: 'Sign Out Admin?',
      description: 'Do you want to sign out and end your active admin session?',
      confirmText: 'Sign Out',
      onConfirm: () async {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        
        await _storage.remove('isLoggedIn');
        await _storage.remove('userPhone');
        await _storage.remove('userRole');
        
        Get.offAllNamed(Routes.LOGIN);
        AppSnackBar.showSuccess(title: 'Logged Out', message: 'Session closed successfully.');
      },
    );
  }
}
