import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Selected trip for tracking timeline in dashboard
  final RxString selectedTripId = ''.obs;

  // Dashboard filter fields
  final RxString searchQuery = ''.obs;
  final RxString selectedStatus = 'All Status'.obs;
  final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);

  // Database lists
  final RxList<Map<String, dynamic>> trips = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> trucks = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> vendors = <Map<String, dynamic>>[].obs;

  StreamSubscription? _tripsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _trucksSub;
  StreamSubscription? _vendorsSub;

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
    _vendorsSub?.cancel();
    _trucksSub?.cancel();
    super.onClose();
  }

  // Live admin dashboard: trips + expenses + users (driver availability) stay
  // current — no manual refresh needed.
  void _startLiveUpdates() {
    _tripsSub = _firebaseService.watchAllTrips().listen((list) {
      trips.assignAll(list.map(_mapTrip).toList());
      if (selectedTripId.value.isEmpty && trips.isNotEmpty) {
        final active = trips.firstWhereOrNull((t) => t['isActive'] == true);
        if (active != null) {
          selectedTripId.value = active['id'].toString();
        } else {
          selectedTripId.value = trips.first['id'].toString();
        }
      }
    });
    _expensesSub = _firebaseService.watchAllExpenses().listen((list) {
      expenses.assignAll(list);
    });
    _usersSub = _firebaseService.watchAllUsers().listen(users.assignAll);
    _trucksSub = _firebaseService.watchAllTrucks().listen(trucks.assignAll);
    _vendorsSub = _firebaseService.watchVendors().listen(vendors.assignAll);
  }

  // ---------------------------------------------------------------------------
  // DAILY TRUCK-ASSIGNMENT GATE + DRIVER ROSTER
  // Admin's first daily task is to assign a truck to every driver. Until every
  // on-duty (non-leave) driver has a truck, no trip can be created.
  // ---------------------------------------------------------------------------

  /// All non-admin users (drivers), leave or not.
  List<Map<String, dynamic>> get allDrivers => users
      .where((u) => (u['role'] ?? 'driver') != 'admin')
      .toList();

  bool isOnLeave(Map<String, dynamic> user) =>
      user['onLeave'] == true || user['availability'] == 'on_leave';

  /// Drivers expected to work today (not on leave).
  List<Map<String, dynamic>> get rosterDrivers =>
      allDrivers.where((u) => !isOnLeave(u)).toList();

  bool driverHasTruck(String phone) =>
      trucks.any((t) => (t['assignedTo'] ?? '').toString() == phone);

  /// On-duty drivers who still don't have a truck assigned (the admin's pending
  /// morning task). Drives the trip-creation gate + the warning message.
  List<Map<String, dynamic>> get driversWithoutTruck => rosterDrivers
      .where((u) => !driverHasTruck((u['phone'] ?? '').toString()))
      .toList();

  /// True once every on-duty driver has a truck — only then can trips be made.
  bool get canCreateTrip =>
      rosterDrivers.isNotEmpty && driversWithoutTruck.isEmpty;

  /// Admin marks a driver on leave / back on duty.
  Future<void> setDriverOnLeave(String phone, bool onLeave) async {
    try {
      await _firebaseService.setDriverLeave(phone, onLeave);
      AppSnackBar.showSuccess(
        title: onLeave ? 'Marked On Leave' : 'Back On Duty',
        message: onLeave
            ? 'Driver ko aaj ke liye leave par daal diya.'
            : 'Driver wapas duty par hai.',
      );
    } catch (e) {
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // VENDORS  (predefined pickup sources)
  // ---------------------------------------------------------------------------

  Future<void> saveVendor(Map<String, dynamic> vendorData) async {
    AppPopup.showLoading(message: 'Saving vendor...');
    try {
      await _firebaseService.saveVendor(vendorData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Vendor Saved', message: 'Vendor details save ho gaye.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteVendor(String id, {String name = ''}) async {
    AppPopup.showConfirmation(
      title: 'Delete Vendor?',
      description:
          'Kya aap ${name.isNotEmpty ? '"$name"' : 'is vendor'} ko delete karna chahte hain?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting...');
        try {
          await _firebaseService.deleteVendor(id);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
              title: 'Deleted', message: 'Vendor hata diya gaya.');
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  /// Set the drop destination for a trip (typically while the truck is
  /// loading). The driver sees it only after the load is approved.
  Future<void> setDestination(String tripId, String dropCity,
      String dropLocation,
      {String customerName = '', String customerAddress = ''}) async {
    AppPopup.showLoading(message: 'Setting destination...');
    try {
      await _firebaseService.setTripDestination(tripId,
          dropCity: dropCity,
          dropLocation: dropLocation,
          customerName: customerName,
          customerAddress: customerAddress);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Destination Set 📍',
          message: '$dropCity — $dropLocation. Ab load approve kar sakte hain.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  /// Assign a truck to a driver (morning duty allocation). The driver gets a
  /// notification to inspect + accept it.
  Future<void> assignTruck(String truckNo, String driverPhone,
      {String? model}) async {
    AppPopup.showLoading(message: 'Assigning truck...');
    try {
      await _firebaseService.assignTruckToDriver(truckNo, driverPhone,
          model: model);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Truck Assigned 🚛',
          message: '$truckNo assigned. Driver ko inspection ke liye '
               'notification bhej di gayi.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
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
        'vendorName': trip.vendorName,
        'vendorLocation': trip.vendorLocation,
        'materialName': trip.materialName,
        'productName': trip.productName,
        'passHolderName': trip.passHolderName,
        'royaltyName': trip.royaltyName,
        'loadingPassId': trip.loadingPassId,
        'minPassId': trip.minPassId,
        'maxPassId': trip.maxPassId,
        'pickupDistrict': trip.pickupDistrict,
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

  DateTime? _lastBackPressAt;

  /// Back on a non-Dashboard tab returns to Dashboard; on Dashboard the app
  /// exits only on a second back press within 2 seconds (same as driver Home).
  void handleBackPress() {
    if (currentTabIndex.value != 0) {
      changeTabIndex(0);
      return;
    }

    final now = DateTime.now();
    final firstPressOrExpired = _lastBackPressAt == null ||
        now.difference(_lastBackPressAt!) > const Duration(seconds: 2);

    if (firstPressOrExpired) {
      _lastBackPressAt = now;
      AppSnackBar.showInfo(
        title: 'Exit App',
        message: 'Press back again to exit.',
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    SystemNavigator.pop();
  }

  /// Drivers who are currently on duty (checked-in Available) OR running an
  /// active trip. Used by the "Active Drivers" stat + the Active Drivers screen.
  List<Map<String, dynamic>> get activeDrivers {
    final activePhones = trips
        .where((t) => t['isActive'] == true)
        .map((t) => (t['driverPhone'] ?? '').toString())
        .where((p) => p.isNotEmpty)
        .toSet();
    return users.where((u) {
      if ((u['role'] ?? 'driver') == 'admin') return false;
      final phone = (u['phone'] ?? '').toString();
      return u['availability'] == 'available' || activePhones.contains(phone);
    }).toList();
  }

  Map<String, dynamic>? activeTripForDriver(String phone) {
    try {
      return trips.firstWhere(
          (t) => t['isActive'] == true && (t['driverPhone'] ?? '').toString() == phone);
    } catch (_) {
      return null;
    }
  }

  // Filter helper functions
  bool _matchesQuery(String truckNo, String assignedPhone) {
    if (searchQuery.value.isEmpty) return true;
    final query = searchQuery.value.toLowerCase().trim();
    if (truckNo.toLowerCase().contains(query)) return true;
    if (assignedPhone.toLowerCase().contains(query)) return true;
    final name = driverNameFor(assignedPhone).toLowerCase();
    if (name.contains(query)) return true;
    return false;
  }

  bool _matchesStatus(Map<String, dynamic> truck, Map<String, dynamic>? trip) {
    if (selectedStatus.value == 'All Status') return true;
    final status = selectedStatus.value;
    if (status == 'Idle') {
      return (truck['assignedTo'] ?? '').toString().isEmpty;
    }
    if (status == 'Breakdown') {
      return truck['inspectionStatus'] == 'problem';
    }
    if (trip == null) return false;
    final tripStatus = trip['status'] ?? '';
    if (status == 'Loading') {
      return tripStatus == 'LOADING' || tripStatus == 'LOAD_REQUESTED';
    }
    if (status == 'On The Way') {
      return tripStatus == 'EN_ROUTE_VENDOR' ||
          tripStatus == 'ACTIVE NOW' ||
          tripStatus == 'DELIVERY_REQUESTED';
    }
    return false;
  }

  bool _matchesDate(Map<String, dynamic>? trip) {
    if (selectedDate.value == null) return true;
    if (trip == null) return false;
    final tripDateStr = (trip['date'] ?? '').toString();
    if (tripDateStr.isEmpty) return false;
    
    final formattedSelected = "${selectedDate.value!.year}-${selectedDate.value!.month.toString().padLeft(2, '0')}-${selectedDate.value!.day.toString().padLeft(2, '0')}";
    return tripDateStr.contains(formattedSelected) || formattedSelected.contains(tripDateStr);
  }

  // ---- Truck kanban helpers (dashboard) ----
  List<Map<String, dynamic>> get idleTrucks => trucks
      .where((t) =>
          (t['assignedTo'] ?? '').toString().isEmpty &&
          _matchesQuery((t['truckNo'] ?? '').toString(), '') &&
          (selectedStatus.value == 'All Status' || selectedStatus.value == 'Idle'))
      .toList();

  List<Map<String, dynamic>> get problemTrucks => trucks
      .where((t) =>
          t['inspectionStatus'] == 'problem' &&
          _matchesQuery((t['truckNo'] ?? '').toString(), (t['assignedTo'] ?? '').toString()) &&
          (selectedStatus.value == 'All Status' || selectedStatus.value == 'Breakdown'))
      .toList();

  List<Map<String, dynamic>> get assignedTrucks => trucks.where((t) {
        final assignedTo = (t['assignedTo'] ?? '').toString();
        if (assignedTo.isEmpty || t['inspectionStatus'] == 'problem') return false;
        final trip = currentTripForDriver(assignedTo);
        return _matchesQuery((t['truckNo'] ?? '').toString(), assignedTo) &&
            _matchesStatus(t, trip) &&
            _matchesDate(trip);
      }).toList();

  int get completedTripsCount =>
      trips.where((t) => t['status'] == 'DELIVERED').length;

  int get activeTripsCount => trips.where((t) => t['isActive'] == true).length;

  /// The driver's running (not delivered/rejected) trip, for assigned-truck
  /// card details on the dashboard.
  Map<String, dynamic>? currentTripForDriver(String phone) =>
      trips.firstWhereOrNull((t) =>
          (t['driverPhone'] ?? '').toString() == phone &&
          t['status'] != 'DELIVERED' &&
          t['status'] != 'REJECTED');

  Future<void> completeTrip(String tripId) async {
    AppPopup.showLoading(message: 'Completing trip...');
    try {
      await _firebaseService.updateTripMilestone(
        tripId,
        4,
        status: 'DELIVERED',
        locationName: 'Completed by Admin',
      );
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
        title: 'Trip Completed ✅',
        message: 'Trip $tripId has been marked as delivered.',
      );
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  String driverNameFor(String phone) {
    final u = users.firstWhereOrNull((u) => (u['phone'] ?? '') == phone);
    final name = (u?['name'] ?? '').toString();
    return name.isEmpty ? phone : name;
  }

  /// Admin marks a problem-truck active again (issue resolved).
  Future<void> markTruckActive(String truckNo) async {
    AppPopup.showLoading(message: 'Marking active...');
    try {
      await _firebaseService.clearTruckIssue(truckNo);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Truck Active ✅',
          message: '$truckNo ready — driver ko inform kar diya.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  void openActiveDrivers() => Get.toNamed(Routes.ACTIVE_DRIVERS);

  void openDriverDetail(String phone) =>
      Get.toNamed(Routes.DRIVER_DETAIL, arguments: {'phone': phone});

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
    AppPopup.showLoading(message: 'Assigning Trip...');
    try {
      // Trip id is auto-generated — the admin never types it.
      var tripId = (tripData['id'] ?? '').toString();
      if (tripId.isEmpty) {
        tripId = await _firebaseService.generateTripId();
        tripData['id'] = tripId;
      }
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

  /// Registers a driver and uploads their documents (photo, driving licence,
  /// heavy-vehicle licence). Each image is uploaded to Storage and its URL is
  /// saved on the user doc so the driver record is complete.
  Future<void> createDriverWithDocuments(
    Map<String, dynamic> userData, {
    Uint8List? photoBytes,
    Uint8List? drivingLicenceBytes,
    Uint8List? heavyLicenceBytes,
  }) async {
    final phone = userData['phone'] as String;
    AppPopup.showLoading(message: 'Uploading documents & creating profile...');
    try {
      if (photoBytes != null) {
        final url = await _firebaseService.uploadDriverDocument(
            phone, 'photo', photoBytes);
        if (url.isNotEmpty) userData['avatarUrl'] = url;
      }
      if (drivingLicenceBytes != null) {
        final url = await _firebaseService.uploadDriverDocument(
            phone, 'driving_licence', drivingLicenceBytes);
        if (url.isNotEmpty) userData['drivingLicenceUrl'] = url;
      }
      if (heavyLicenceBytes != null) {
        final url = await _firebaseService.uploadDriverDocument(
            phone, 'heavy_licence', heavyLicenceBytes);
        if (url.isNotEmpty) userData['heavyLicenceUrl'] = url;
      }
      await _firebaseService.saveUser(phone, userData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Driver Added', message: 'Driver profile registered.');
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

  // --- TRUCK INSPECTION APPROVALS ---
  Future<void> approveInspection(String truckNo) async {
    AppPopup.showLoading(message: 'Approving inspection...');
    try {
      await _firebaseService.approveTruckInspection(truckNo);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
        title: 'Inspection Approved ✅',
        message: 'Truck $truckNo inspection approved. Driver ko notification bhej di gayi.',
      );
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> rejectInspection(String truckNo) async {
    AppPopup.showLoading(message: 'Rejecting inspection...');
    try {
      await _firebaseService.rejectTruckInspection(truckNo);
      AppPopup.hideLoading();
      AppSnackBar.showInfo(
        title: 'Inspection Rejected ❌',
        message: 'Truck $truckNo inspection rejected. Driver ko inspect karne ko keh diya hai.',
      );
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
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

  Future<void> clearDatabase() async {
    try {
      await _firebaseService.clearDatabase();
      selectedTripId.value = '';
      await loadData();
    } catch (_) {}
  }
}
