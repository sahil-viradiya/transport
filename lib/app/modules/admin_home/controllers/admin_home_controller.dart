import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/data/services/auth_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';
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
  final RxString selectedExpenseDriver = ''.obs;
  final RxString selectedExpenseTrip = ''.obs;
  final RxString selectedExpenseStatus = 'All'.obs;

  // Database lists
  final RxList<Map<String, dynamic>> trips = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> trucks = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> vendors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> customers = <Map<String, dynamic>>[].obs;

  StreamSubscription? _tripsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _trucksSub;
  StreamSubscription? _vendorsSub;
  StreamSubscription? _customersSub;

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
    _customersSub?.cancel();
    _trucksSub?.cancel();
    tripSearchController.dispose();
    super.onClose();
  }

  /// Set when the live streams are being rejected by Firestore (almost always
  /// security rules that haven't been deployed). Without this, a denied read
  /// just left every list empty — the dashboard showed 0 trucks / 0 drivers /
  /// 0 trips with no hint that anything was wrong.
  final RxString dataError = ''.obs;

  /// Every collection whose stream is currently failing. Tracked as a set (not
  /// a single message) because each stream errors separately — reporting only
  /// the last one hid the fact that several were blocked at once.
  final Set<String> _deniedCollections = {};
  final Set<String> _erroredCollections = {};

  void _onStreamError(String what, Object e) {
    final msg = e.toString();
    final denied =
        msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');
    if (denied) {
      _deniedCollections.add(what);
    } else {
      _erroredCollections.add(what);
    }

    final parts = <String>[];
    if (_deniedCollections.isNotEmpty) {
      final list = (_deniedCollections.toList()..sort()).join(', ');
      parts.add('Firestore ne in collections ko block kiya '
          '(permission-denied): $list. '
          'Rules deploy karein: firebase deploy --only firestore:rules');
    }
    if (_erroredCollections.isNotEmpty) {
      final list = (_erroredCollections.toList()..sort()).join(', ');
      parts.add('Load nahi hua: $list.');
    }
    dataError.value = parts.join('  •  ');

    // ignore: avoid_print
    print('[AdminHome] $what stream error: $e');
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
    }, onError: (e) => _onStreamError('trips', e));
    _expensesSub = _firebaseService.watchAllExpenses().listen((list) {
      expenses.assignAll(list);
    }, onError: (e) => _onStreamError('expenses', e));
    _usersSub = _firebaseService
        .watchAllUsers()
        .listen(users.assignAll, onError: (e) => _onStreamError('drivers', e));
    _trucksSub = _firebaseService
        .watchAllTrucks()
        .listen(trucks.assignAll, onError: (e) => _onStreamError('trucks', e));
    _vendorsSub = _firebaseService.watchVendors().listen(vendors.assignAll,
        onError: (e) => _onStreamError('vendors', e));
    _customersSub = _firebaseService.watchCustomers().listen(customers.assignAll,
        onError: (e) => _onStreamError('customers', e));
  }

  // ---------------------------------------------------------------------------
  // DAILY TRUCK-ASSIGNMENT GATE + DRIVER ROSTER
  // Admin's first daily task is to assign a truck to every driver. Until every
  // on-duty (non-leave) driver has a truck, no trip can be created.
  // ---------------------------------------------------------------------------

  /// All non-admin users (drivers), leave or not.
  List<Map<String, dynamic>> get allDrivers =>
      users.where((u) => (u['role'] ?? 'driver') != 'admin').toList();

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

  // ---------------------------------------------------------------------------
  // CUSTOMERS (delivery destinations)
  // ---------------------------------------------------------------------------

  Future<void> saveCustomer(Map<String, dynamic> customerData) async {
    AppPopup.showLoading(message: 'Saving customer...');
    try {
      await _firebaseService.saveCustomer(customerData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Customer Saved', message: 'Customer details save ho gaye.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteCustomer(String id, {String name = ''}) async {
    AppPopup.showConfirmation(
      title: 'Delete Customer?',
      description:
          'Kya aap ${name.isNotEmpty ? '"$name"' : 'is customer'} ko delete karna chahte hain?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting...');
        try {
          await _firebaseService.deleteCustomer(id);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
              title: 'Deleted', message: 'Customer hata diya gaya.');
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ADMIN TRIPS TAB: search + status filter + pagination
  // ---------------------------------------------------------------------------
  final RxString tripStatusFilter =
      'All'.obs; // All|En Route|Pending|Completed|Cancelled
  final RxString tripSearch = ''.obs;
  final tripSearchController = TextEditingController();
  final Rx<DateTime?> tripDateFilter = Rx<DateTime?>(null);
  final RxInt tripPage = 0.obs;
  final RxInt tripsPerPage = 10.obs;

  static const _enRouteStatuses = {
    'EN_ROUTE_VENDOR',
    'LOADING',
    'LOAD_REQUESTED',
    'ACTIVE NOW',
    'DELIVERY_REQUESTED',
  };

  static const _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  bool _tripMatchesFilter(Map<String, dynamic> t) {
    final s = (t['status'] ?? '').toString();
    switch (tripStatusFilter.value) {
      case 'En Route':
        return _enRouteStatuses.contains(s);
      case 'Pending':
        return s == 'PENDING' || s == 'ASSIGNED';
      case 'Completed':
        return s == 'DELIVERED';
      case 'Cancelled':
        return s == 'REJECTED';
      default:
        return true;
    }
  }

  bool _tripMatchesSearch(Map<String, dynamic> t) {
    final q = tripSearch.value.trim().toLowerCase();
    if (q.isEmpty) return true;
    final driver =
        driverNameFor((t['driverPhone'] ?? '').toString()).toLowerCase();
    return [
          t['id'],
          t['vendorName'],
          t['truckNo'],
          t['pickupCity'],
          t['dropCity']
        ].any((v) => (v ?? '').toString().toLowerCase().contains(q)) ||
        driver.contains(q);
  }

  bool _tripMatchesDate(Map<String, dynamic> t) {
    final d = tripDateFilter.value;
    if (d == null) return true;
    final tag = '${d.day} ${_monthAbbr[d.month - 1]}'; // e.g. "13 Jul"
    return (t['date'] ?? '').toString().contains(tag);
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

  /// Trips after applying the tab's search + status + date filters.
  List<Map<String, dynamic>> get filteredTrips {
    final list = trips
        .where((t) =>
            _tripMatchesFilter(t) &&
            _tripMatchesSearch(t) &&
            _tripMatchesDate(t))
        .toList();
    list.sort((a, b) {
      final weightA = _statusSortWeight((a['status'] ?? '').toString());
      final weightB = _statusSortWeight((b['status'] ?? '').toString());
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      final priorityA = a['priority'] == true;
      final priorityB = b['priority'] == true;
      if (priorityA != priorityB) {
        return priorityA ? -1 : 1;
      }
      return 0;
    });
    return list;
  }

  int get tripPageCount {
    final per = tripsPerPage.value;
    if (per <= 0) return 1;
    final n = filteredTrips.length;
    final pages = (n + per - 1) ~/ per;
    return pages < 1 ? 1 : pages;
  }

  /// The current page of filtered trips.
  List<Map<String, dynamic>> get pagedTrips {
    final all = filteredTrips;
    final per = tripsPerPage.value;
    var page = tripPage.value;
    if (page > tripPageCount - 1) page = tripPageCount - 1;
    if (page < 0) page = 0;
    final start = page * per;
    if (start >= all.length) return const [];
    final end = (start + per) > all.length ? all.length : (start + per);
    return all.sublist(start, end);
  }

  /// Count of trips per status for the filter chips (uses the search + date
  /// filters but ignores the status filter so each chip shows its own total).
  int tripStatusCount(String filter) {
    final base = trips
        .where((t) => _tripMatchesSearch(t) && _tripMatchesDate(t))
        .toList();
    switch (filter) {
      case 'En Route':
        return base
            .where((t) => _enRouteStatuses.contains((t['status'] ?? '')))
            .length;
      case 'Pending':
        return base
            .where((t) =>
                (t['status'] ?? '') == 'PENDING' ||
                (t['status'] ?? '') == 'ASSIGNED')
            .length;
      case 'Completed':
        return base.where((t) => (t['status'] ?? '') == 'DELIVERED').length;
      case 'Cancelled':
        return base.where((t) => (t['status'] ?? '') == 'REJECTED').length;
      default:
        return base.length;
    }
  }

  void setTripFilter(String f) {
    tripStatusFilter.value = f;
    tripPage.value = 0;
  }

  void setTripSearch(String q) {
    tripSearch.value = q;
    tripPage.value = 0;
  }

  void setTripDateFilter(DateTime? d) {
    tripDateFilter.value = d;
    tripPage.value = 0;
  }

  void setTripsPerPage(int n) {
    tripsPerPage.value = n;
    tripPage.value = 0;
  }

  void goToTripPage(int p) {
    if (p < 0 || p > tripPageCount - 1) return;
    tripPage.value = p;
  }

  void clearTripFilters() {
    tripStatusFilter.value = 'All';
    tripSearch.value = '';
    tripSearchController.clear();
    tripDateFilter.value = null;
    tripPage.value = 0;
  }

  /// Set the drop destination for a trip (typically while the truck is
  /// loading). The driver sees it only after the load is approved.
  Future<void> setDestination(
      String tripId, String dropCity, String dropLocation,
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
          message:
              '$dropCity — $dropLocation. Ab load approve kar sakte hain.');
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
        'loadingPhotoUrl': trip.loadingPhotoUrl,
        'gatePassPhotoUrl': trip.gatePassPhotoUrl,
        'loadingPassGeneratedAt': trip.loadingPassGeneratedAt,
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
      return trips.firstWhere((t) =>
          t['isActive'] == true &&
          (t['driverPhone'] ?? '').toString() == phone);
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

    final formattedSelected =
        "${selectedDate.value!.year}-${selectedDate.value!.month.toString().padLeft(2, '0')}-${selectedDate.value!.day.toString().padLeft(2, '0')}";
    return tripDateStr.contains(formattedSelected) ||
        formattedSelected.contains(tripDateStr);
  }

  // ---- Truck kanban helpers (dashboard) ----
  List<Map<String, dynamic>> get idleTrucks => trucks
      .where((t) =>
          (t['assignedTo'] ?? '').toString().isEmpty &&
          _matchesQuery((t['truckNo'] ?? '').toString(), '') &&
          (selectedStatus.value == 'All Status' ||
              selectedStatus.value == 'Idle'))
      .toList();

  List<Map<String, dynamic>> get problemTrucks => trucks
      .where((t) =>
          t['inspectionStatus'] == 'problem' &&
          _matchesQuery((t['truckNo'] ?? '').toString(),
              (t['assignedTo'] ?? '').toString()) &&
          (selectedStatus.value == 'All Status' ||
              selectedStatus.value == 'Breakdown'))
      .toList();

  List<Map<String, dynamic>> get assignedTrucks => trucks.where((t) {
        final assignedTo = (t['assignedTo'] ?? '').toString();
        if (assignedTo.isEmpty || t['inspectionStatus'] == 'problem')
          return false;
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

  String driverAvatarFor(String phone) {
    final u = users.firstWhereOrNull((u) => (u['phone'] ?? '') == phone);
    return (u?['avatarUrl'] ?? '').toString();
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
      // await _firebaseService.migratePhoneKeys();
      // Fetch users
      final fetchedUsers = await _firebaseService.getUsers();
      users.assignAll(fetchedUsers);
      _syncExistingAvatars(fetchedUsers);

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

  Future<void> _syncExistingAvatars(
      List<Map<String, dynamic>> fetchedUsers) async {
    for (final u in fetchedUsers) {
      if ((u['role'] ?? 'driver') == 'driver') {
        final phone = (u['phone'] ?? '').toString();
        if (phone.isNotEmpty) {
          try {
            final profile = await _firebaseService.getDriverProfile(phone);
            final dbAvatar = (profile['avatarUrl'] ?? '').toString();
            final currentAvatar = (u['avatarUrl'] ?? '').toString();
            if (dbAvatar.isNotEmpty && dbAvatar != currentAvatar) {
              await _firebaseService.saveUser(phone, {'avatarUrl': dbAvatar});
            }
          } catch (_) {}
        }
      }
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
      AppSnackBar.showSuccess(
          title: 'Trip Updated', message: 'Trip details modified.');
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
          AppSnackBar.showSuccess(
              title: 'Deleted', message: 'Trip removed from database.');
          await loadData();
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  Future<void> approveTripDelivery(String tripId) async {
    AppPopup.showLoading(message: 'Approving Delivery...');
    try {
      // Force transition to DELIVERY_REQUESTED if not set (fallback safety)
      final doc = await _firebaseService.getTripData(tripId) ?? {};
      if (doc['status'] != 'DELIVERY_REQUESTED') {
        await _firebaseService
            .saveTrip(tripId, {'status': 'DELIVERY_REQUESTED'});
      }
      await _firebaseService.approveDelivery(tripId);
      AppPopup.hideLoading();
      Get.snackbar('Approved', 'Trip delivery has been approved successfully.',
          snackPosition: SnackPosition.BOTTOM);
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> rejectTripDelivery(String tripId, String reason) async {
    AppPopup.showLoading(message: 'Rejecting Delivery...');
    try {
      // Force transition to DELIVERY_REQUESTED if not set (fallback safety)
      final doc = await _firebaseService.getTripData(tripId) ?? {};
      if (doc['status'] != 'DELIVERY_REQUESTED') {
        await _firebaseService
            .saveTrip(tripId, {'status': 'DELIVERY_REQUESTED'});
      }
      await _firebaseService.rejectDelivery(tripId, reason: reason);
      AppPopup.hideLoading();
      Get.snackbar('Rejected', 'Trip delivery has been rejected.',
          snackPosition: SnackPosition.BOTTOM);
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  // --- TRUCK CRUD ACTIONS ---
  Future<void> createTruck(Map<String, dynamic> truckData) async {
    final truckNo = truckData['truckNo'] as String;
    AppPopup.showLoading(message: 'Registering Truck $truckNo...');
    try {
      await _firebaseService.saveTruck(truckNo, truckData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Truck Registered', message: 'Truck added successfully.');
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
      AppSnackBar.showSuccess(
          title: 'Truck Updated', message: 'Truck profile updated.');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteTruck(String truckNo) async {
    AppPopup.showConfirmation(
      title: 'Delete Truck?',
      description:
          'Are you sure you want to permanently delete Truck $truckNo?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting Truck...');
        try {
          await _firebaseService.deleteTruck(truckNo);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
              title: 'Deleted', message: 'Truck removed from database.');
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
      AppSnackBar.showSuccess(
          title: 'User Added', message: 'User profile registered.');
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
      AppSnackBar.showSuccess(
          title: 'Role Updated', message: 'Role set to: $newRole');
      await loadData();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<void> deleteUser(String phone) async {
    AppPopup.showConfirmation(
      title: 'Delete User?',
      description:
          'Are you sure you want to permanently delete profile for $phone?',
      confirmText: 'Delete',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting profile...');
        try {
          await _firebaseService.deleteUser(phone);
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
              title: 'Deleted', message: 'User profile removed.');
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
      description:
          'This claim will be marked rejected and the driver notified.',
      confirmText: 'Reject',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Rejecting...');
        try {
          await _firebaseService.rejectExpenseById(id,
              reason: reasonCtrl.text.trim());
          AppPopup.hideLoading();
          AppSnackBar.showInfo(
              title: 'Expense Rejected',
              message: 'The driver has been notified.');
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
        message:
            'Truck $truckNo inspection approved. Driver ko notification bhej di gayi.',
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
        message:
            'Truck $truckNo inspection rejected. Driver ko inspect karne ko keh diya hai.',
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
        await Get.find<AuthService>().signOut();
        AppSnackBar.showSuccess(
            title: 'Logged Out', message: 'Session closed successfully.');
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

  Future<void> updateAdminProfile(
      String phone, String name, String avatarUrl) async {
    AppPopup.showLoading(message: 'Updating Profile...');
    try {
      await _firebaseService.saveUser(phone, {
        'name': name,
        'avatarUrl': avatarUrl,
      });
      final session = Get.find<SessionService>();
      await session.updateCachedProfile(name: name, avatarUrl: avatarUrl);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Profile Updated',
          message: 'Admin profile updated successfully.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    }
  }

  Future<String> uploadAvatar(Uint8List bytes, String phone) async {
    return await _firebaseService.uploadDriverAvatar(bytes, phone);
  }
}
