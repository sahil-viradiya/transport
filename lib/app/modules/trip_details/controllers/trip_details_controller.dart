import 'dart:async';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/session_service.dart';

class TripDetailsController extends GetxController {
  // Journey state toggles
  final RxBool isJourneyStarted = false.obs;
  
  // Speed and sync variables for active tracking
  final RxInt speed = 64.obs;
  final RxString lastSynced = '2 mins ago'.obs;

  // Active milestone index (1 = Reached Pickup, 2 = Loaded, 3 = Reached Drop)
  final RxInt currentMilestone = 2.obs; // Default to loaded stage matching design mockup

  // Active route coordinates or estimates
  final RxString remainingDistance = '112 KM'.obs;
  final RxString estimatedTime = '14:45'.obs; // Next Stop ETA
  final RxInt fuelConsumed = 42.obs;
  final RxString currentAddress = 'Locating...'.obs;

  // Proof of delivery info
  final RxString podUrl = ''.obs;
  final RxString remarks = ''.obs;

  // Journey details matching reference layout (Left Screen)
  late String tripId;
  // Reactive so they refresh when live Firestore data arrives (e.g. an admin
  // opening a driver's trip that isn't in their local TripsController list).
  final RxString vehicleNo = ''.obs;
  final RxString consignmentNo = ''.obs;
  
  // Departure Info
  final RxString departureTitle = ''.obs;
  final RxString departureSubtitle = ''.obs;
  final RxString departureTime = ''.obs;

  // Destination Info
  final RxString destinationTitle = ''.obs;
  final RxString destinationSubtitle = ''.obs;

  List<double> _getCoordinates(String title, String city) {
    double lat = 18.9482;
    double lng = 72.9469;
    
    final search = '${title.trim()} ${city.trim()}'.toLowerCase();
    
    locationCoordinates.forEach((key, value) {
      if (search.contains(key.toLowerCase())) {
        lat = value[0];
        lng = value[1];
      }
    });
    
    return [lat, lng];
  }

  @override
  void onInit() {
    super.onInit();
    
    // Set default values matching TRP-882910 fallback
    tripId = 'TRP-882910';
    vehicleNo.value = 'HR-22-9012';
    consignmentNo.value = '#9012';
    departureTitle.value = 'JNPT Port Terminal';
    departureSubtitle.value = 'Navi Mumbai, Maharashtra';
    departureTime.value = 'Today, 06:30 AM';
    destinationTitle.value = 'Indore Logistics Hub';
    destinationSubtitle.value = 'Pithampur, Madhya Pradesh';

    String pickupCity = 'Mumbai';
    String dropCity = 'Indore';
    double startLat = 18.9482;
    double startLng = 72.9469;
    double endLat = 22.6208;
    double endLng = 75.8039;
    bool hasCoords = false;

    final args = Get.arguments;
    if (args != null && args is Map) {
      if (args['isAlreadyActive'] == true) {
        isJourneyStarted.value = true;
      }
      
      final argTripId = args['tripId'];
      if (argTripId != null && argTripId.toString().isNotEmpty) {
        // Always trust the argument id — even when the trip isn't in the local
        // TripsController list (e.g. an admin opening a driver's trip), so the
        // live Firestore load/watch below targets the right document.
        tripId = argTripId.toString();
        try {
          final tripsController = Get.find<TripsController>();
          final trip = tripsController.allTrips.firstWhere((t) => t.id == argTripId);
          vehicleNo.value = trip.truckNo;
          
          final cleanIdDigits = trip.id.replaceAll(RegExp(r'\D'), '');
          consignmentNo.value = '#${cleanIdDigits.isNotEmpty ? cleanIdDigits : "9012"}';
          
          departureTitle.value = trip.pickupLocation;
          departureSubtitle.value = '${trip.pickupCity}, India';
          departureTime.value = trip.date;
          tripStatus.value = trip.status;
          if (_destinationRevealedStatuses.contains(trip.status)) {
            destinationTitle.value = trip.dropLocation;
            destinationSubtitle.value = '${trip.dropCity}, India';
          } else {
            destinationTitle.value = 'Destination pending';
            destinationSubtitle.value =
                'Load approve hone ke baad admin destination dikhayega';
          }
          
          pickupCity = trip.pickupCity;
          dropCity = trip.dropCity;

          if (trip.pickupLatitude != null && trip.pickupLongitude != null) {
            startLat = trip.pickupLatitude!;
            startLng = trip.pickupLongitude!;
            hasCoords = true;
          }
          if (trip.dropLatitude != null && trip.dropLongitude != null) {
            endLat = trip.dropLatitude!;
            endLng = trip.dropLongitude!;
            hasCoords = true;
          }

          if (trip.status == 'DELIVERED') {
            isJourneyStarted.value = true;
            currentMilestone.value = 4;
            remainingDistance.value = '0 KM';
            estimatedTime.value = 'Delivered';
            speed.value = 0;
          }
        } catch (_) {
          // Keep defaults
        }
      }
    }

    if (!hasCoords) {
      // Calculate initial distance and ETA from fallback
      final startCoords = _getCoordinates(departureTitle.value, pickupCity);
      startLat = startCoords[0];
      startLng = startCoords[1];
      
      final endCoords = _getCoordinates(destinationTitle.value, dropCity);
      endLat = endCoords[0];
      endLng = endCoords[1];
    }
    
    final locationService = Get.find<LocationService>();
    final initialDistance = locationService.calculateDistance(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    remainingDistance.value = '${initialDistance.toStringAsFixed(1)} KM';
    estimatedTime.value = locationService.estimateTravelTime(initialDistance);

    if (isJourneyStarted.value) {
      startLocationUpdates();
    }
    _loadLiveTripData();

    // Auto-activate the moment the admin approves the load (status → ACTIVE NOW).
    try {
      _tripStatusSub =
          Get.find<FirebaseService>().watchTripData(tripId).listen((data) {
        if (data == null) return;
        _applyLiveStatus(data);
        final status = data['status'];
        if (status == 'ACTIVE NOW' && !isJourneyStarted.value) {
          isJourneyStarted.value = true;
          if (currentMilestone.value < 3) currentMilestone.value = 3;
          startLocationUpdates();
          AppSnackBar.showSuccess(
            title: 'Trip Activated ✅',
            message: 'Admin approved your load. Trip is now active!',
          );
        }
        if (status == 'DELIVERED' && currentMilestone.value < 4) {
          currentMilestone.value = 4;
          remainingDistance.value = '0 KM';
          estimatedTime.value = 'Delivered';
          speed.value = 0;
          _locationTimer?.cancel();
          AppSnackBar.showSuccess(
            title: 'Delivery Approved ✅',
            message: 'Admin approved the delivery. Trip complete!',
          );
        }
      });
    } catch (_) {}
  }

  StreamSubscription? _tripStatusSub;

  // Vendor-journey state: ASSIGNED → EN_ROUTE_VENDOR → LOADING →
  // LOAD_REQUESTED → ACTIVE NOW → DELIVERY_REQUESTED → DELIVERED.
  final RxString tripStatus = ''.obs;
  final Rxn<Map<String, dynamic>> tripExtra = Rxn<Map<String, dynamic>>();
  final RxBool showCallAdmin = false.obs;
  Timer? _destReminderTimer;

  String get adminPhone =>
      (tripExtra.value?['assignedBy'] ?? '').toString();

  /// Destination is revealed to the driver only once the load is approved.
  static const _destinationRevealedStatuses = {
    'ACTIVE NOW',
    'DELIVERY_REQUESTED',
    'DELIVERED',
  };

  bool get destinationRevealed =>
      _destinationRevealedStatuses.contains(tripStatus.value);

  /// Label for the single primary action button, driven by the trip status.
  String get primaryActionLabel {
    switch (tripStatus.value) {
      case 'ASSIGNED':
        return 'Start — Vendor ke liye niklo';
      case 'EN_ROUTE_VENDOR':
        return 'Vendor Pahunch Gaya — Loading Shuru';
      case 'LOADING':
        return 'Loading Done — Approval Bhejo';
      case 'LOAD_REQUESTED':
        return 'Admin approval ka intezaar...';
      case 'ACTIVE NOW':
        return 'Deliver — Upload Proof of Delivery';
      case 'DELIVERY_REQUESTED':
        return 'Awaiting Delivery Approval...';
      default:
        return 'Start Journey';
    }
  }

  void _applyLiveStatus(Map<String, dynamic> data) {
    tripStatus.value = (data['status'] ?? '').toString();
    tripExtra.value = data;

    // Destination stays hidden until the load is approved.
    if (destinationRevealed &&
        ((data['dropLocation'] ?? '').toString().isNotEmpty ||
            (data['dropCity'] ?? '').toString().isNotEmpty)) {
      if ((data['dropLocation'] ?? '').toString().isNotEmpty) {
        destinationTitle.value = data['dropLocation'].toString();
      }
      if ((data['dropCity'] ?? '').toString().isNotEmpty) {
        destinationSubtitle.value = '${data['dropCity']}, India';
      }
    } else if (!destinationRevealed) {
      destinationTitle.value = 'Destination pending';
      destinationSubtitle.value =
          'Load approve hone ke baad admin destination dikhayega';
    }

    _syncDestinationReminder(data);
  }

  /// While the load request waits without a destination, remind the admin once
  /// after ~10 minutes and then surface a direct "Call Admin" option.
  void _syncDestinationReminder(Map<String, dynamic> data) {
    final waiting = (data['status'] == 'LOADING' || data['status'] == 'LOAD_REQUESTED' || data['status'] == 'LOAD_REJECTED') &&
        (data['dropCity'] ?? '').toString().trim().isEmpty;
    if (!waiting) {
      _destReminderTimer?.cancel();
      _destReminderTimer = null;
      showCallAdmin.value = false;
      return;
    }

    DateTime? requestedAt;
    final ts = data['loadingStartedAt'] ?? data['loadRequestedAt'];
    try {
      requestedAt = ts is DateTime ? ts : ts?.toDate();
    } catch (_) {}
    requestedAt ??= DateTime.now();
    final reqAt = requestedAt;

    void check() {
      final waited = DateTime.now().difference(reqAt);
      if (waited >= const Duration(minutes: 10)) {
        // One-time reminder to admin (server-side flag keeps it single).
        try {
          Get.find<FirebaseService>().remindSetDestination(tripId);
        } catch (_) {}
        showCallAdmin.value = true;
      }
    }

    check();
    _destReminderTimer ??=
        Timer.periodic(const Duration(minutes: 1), (_) => check());
  }

  // Staged vendor journey — one button, next step depends on the status:
  // ASSIGNED → start to vendor; EN_ROUTE_VENDOR → reached, loading starts;
  // LOADING → request load approval; LOAD_REQUESTED → wait (call admin option).
  void startJourney() {
    switch (tripStatus.value) {
      case 'DELIVERED':
        AppSnackBar.showError(
            title: 'Trip Completed',
            message: 'This trip is already completed.');
        return;

      case 'DELIVERY_REQUESTED':
        AppSnackBar.showInfo(
          title: 'Awaiting Approval',
          message: 'Delivery approval request admin ko bheja ja chuka hai. '
              'Approve hote hi trip complete hogi.',
        );
        return;

      case 'DELIVERY_REJECTED':
        AppSnackBar.showError(
          title: 'Delivery Proof Rejected ⚠️',
          message: 'Proof of Delivery is rejected by admin. Please re-upload it from the main Trips tab.',
        );
        return;

      case 'ACTIVE NOW':
        Get.toNamed(Routes.PROOF_OF_DELIVERY, arguments: {'tripId': tripId})?.then((result) async {
          if (result == true) {
            String driverName = '';
            try {
              driverName = Get.find<SessionService>().name.value;
            } catch (_) {}
            AppPopup.showLoading(message: 'Requesting delivery approval...');
            try {
              final fix = await _realFix();
              final fb = Get.find<FirebaseService>();
              await fb.requestDelivery(
                tripId,
                location: fix.address,
                latitude: fix.lat,
                longitude: fix.lng,
                driverName: driverName,
              );
              AppPopup.hideLoading();
              AppSnackBar.showSuccess(
                title: 'Delivery Sent 📍',
                message: 'Admin ko approval ke liye bheja gaya hai.',
              );
            } catch (e) {
              AppPopup.hideLoading();
              AppSnackBar.showError(title: 'Error', message: e.toString());
            }
          }
        });
        return;

      case 'LOAD_REQUESTED':
        AppSnackBar.showInfo(
          title: 'Awaiting Approval',
          message: 'Load approval request admin ko bheja ja chuka hai. '
              'Approve hote hi trip active hogi.',
        );
        return;

      case 'LOAD_REJECTED':
        AppSnackBar.showError(
          title: 'Load Rejected ⚠️',
          message: 'Loading photos are rejected by admin. Please re-upload them from the main Trips tab.',
        );
        return;

      case 'EN_ROUTE_VENDOR':
        AppPopup.showConfirmation(
          title: 'VENDOR PAHUNCH GAYE?',
          description: 'Vendor ko loading pass dikhakar truck ki loading '
              'shuru ho gayi hai? Admin ko inform kiya jayega (aur wo '
              'destination set karega).',
          confirmText: 'Loading Shuru',
          cancelText: 'Cancel',
          onConfirm: () async {
            AppPopup.showLoading(message: 'Capturing location...');
            try {
              final fix = await _realFix();
              await Get.find<FirebaseService>().startLoading(
                tripId,
                location: fix.address,
                latitude: fix.lat,
                longitude: fix.lng,
                driverName: _driverName,
              );
              AppPopup.hideLoading();
              AppSnackBar.showSuccess(
                title: 'Loading Shuru 📦',
                message: 'Admin ko bata diya — wo destination set karega.',
              );
            } catch (e) {
              AppPopup.hideLoading();
              AppSnackBar.showError(title: 'Error', message: e.toString());
            }
          },
        );
        return;

      case 'LOADING':
        AppPopup.showConfirmation(
          title: 'LOADING COMPLETE?',
          description:
              'Maal load ho gaya? Admin ko approval ke liye request bhejein. '
              'Admin approve karega tabhi trip active hogi aur destination '
              'dikhega.',
          confirmText: 'Send Request',
          cancelText: 'Cancel',
          onConfirm: () async {
            AppPopup.showLoading(message: 'Capturing location...');
            try {
              final fix = await _realFix();
              await Get.find<FirebaseService>().requestLoadApproval(
                tripId,
                pickupLocation: fix.address,
                driverName: _driverName,
                latitude: fix.lat,
                longitude: fix.lng,
              );
              AppPopup.hideLoading();
              AppSnackBar.showSuccess(
                title: 'Request Sent 📦',
                message: 'Admin approve karega tabhi trip active hogi.',
              );
            } catch (e) {
              AppPopup.hideLoading();
              AppSnackBar.showError(title: 'Error', message: e.toString());
            }
          },
        );
        return;

      default:
        // ASSIGNED (or legacy trips): driver leaves for the vendor.
        AppPopup.showConfirmation(
          title: 'VENDOR KE LIYE NIKLEIN?',
          description:
              'Aap vendor ke paas material lene nikal rahe hain? Admin ko '
              '"on the way" status dikhega.',
          confirmText: 'Start',
          cancelText: 'Cancel',
          onConfirm: () async {
            AppPopup.showLoading(message: 'Starting...');
            try {
              final fix = await _realFix();
              await Get.find<FirebaseService>().startToVendor(
                tripId,
                location: fix.address,
                latitude: fix.lat,
                longitude: fix.lng,
                driverName: _driverName,
              );
              AppPopup.hideLoading();
              AppSnackBar.showSuccess(
                title: 'On The Way 🛻',
                message: 'Admin ko inform kar diya. Safe driving!',
              );
            } catch (e) {
              AppPopup.hideLoading();
              AppSnackBar.showError(title: 'Error', message: e.toString());
            }
          },
        );
    }
  }

  /// Direct call to the admin who assigned the trip (last resort when the
  /// destination still isn't set).
  Future<void> callAdmin() async {
    final phone = adminPhone;
    if (phone.isEmpty) {
      AppSnackBar.showWarning(
          title: 'No Number', message: 'Admin ka number nahi mila.');
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {
      AppSnackBar.showInfo(title: 'Admin Number', message: phone);
    }
  }

  Future<void> _loadLiveTripData() async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      final data = await firebaseService.getTripData(tripId);
      if (data != null) {
        final milestone = data['currentMilestone'] as int?;
        final status = data['status'] as String?;
        final dbPodUrl = data['podUrl'] as String?;
        final dbRemarks = data['remarks'] as String?;

        // Populate route/vehicle info straight from Firestore so the screen is
        // correct even when the trip isn't in the local TripsController list
        // (e.g. an admin viewing a driver's trip). Rx fields refresh the UI.
        if ((data['truckNo'] ?? '').toString().isNotEmpty) {
          vehicleNo.value = data['truckNo'].toString();
        }
        if ((data['pickupLocation'] ?? '').toString().isNotEmpty) {
          departureTitle.value = data['pickupLocation'].toString();
        }
        if ((data['pickupCity'] ?? '').toString().isNotEmpty) {
          departureSubtitle.value = '${data['pickupCity']}, India';
        }
        if ((data['date'] ?? '').toString().isNotEmpty) {
          departureTime.value = data['date'].toString();
        }
        final idDigits = tripId.replaceAll(RegExp(r'\D'), '');
        if (idDigits.isNotEmpty) consignmentNo.value = '#$idDigits';

        // Status + destination reveal + reminder handling.
        _applyLiveStatus(data);

        if (dbPodUrl != null) {
          podUrl.value = dbPodUrl;
        }
        if (dbRemarks != null) {
          remarks.value = dbRemarks;
        }
        
        if (status == 'DELIVERED') {
          isJourneyStarted.value = true;
          currentMilestone.value = 4;
          remainingDistance.value = '0 KM';
          estimatedTime.value = 'Delivered';
          speed.value = 0;
          _locationTimer?.cancel();
        } else {
          if (milestone != null) {
            currentMilestone.value = milestone;
          }
          if (status == 'ACTIVE NOW') {
            isJourneyStarted.value = true;
            if (_locationTimer == null || !_locationTimer!.isActive) {
              startLocationUpdates();
            }
          } else {
            isJourneyStarted.value = false;
            _locationTimer?.cancel();
          }
        }
      }
    } catch (_) {}
  }

  // Manifest Details
  final String manifestTitle = 'Industrial Components';
  final String weight = '18.5 Tons';
  final String units = '14 Pallets';

  static const Map<String, List<double>> locationCoordinates = {
    'Mumbai': [18.9482, 72.9469],
    'JNPT Port Terminal': [18.9482, 72.9469],
    'JNPT Terminal': [18.9482, 72.9469],
    'Nagpur': [21.0792, 79.0274],
    'Mihan Hub': [21.0792, 79.0274],
    'Pune': [18.5204, 73.8567],
    'Chakan Plant': [18.7892, 73.8567],
    'Nashik': [19.9975, 73.7898],
    'Ahmedabad': [23.0225, 72.5714],
    'Indore Logistics Hub': [22.6208, 75.8039],
    'Pithampur': [22.6208, 75.8039],
  };

  Timer? _locationTimer;
  // How often the driver app saves its position while a trip is active. Kept at
  // 10 minutes (not seconds) so it's a cheap periodic ping, not live tracking.
  static const Duration _locationSyncInterval = Duration(minutes: 10);
  double simulatedLat = 18.9482;
  double simulatedLng = 72.9469;
  bool isSimulatingMovement = false;

  void startLocationUpdates() {
    // Look up departure coordinates to start simulation from
    double depLat = 18.9482;
    double depLng = 72.9469;
    bool hasDepCoords = false;
    
    try {
      final tripsController = Get.find<TripsController>();
      final trip = tripsController.allTrips.firstWhere((t) => t.id == tripId);
      if (trip.pickupLatitude != null && trip.pickupLongitude != null) {
        depLat = trip.pickupLatitude!;
        depLng = trip.pickupLongitude!;
        hasDepCoords = true;
      }
    } catch (_) {}
    
    if (!hasDepCoords) {
      String pickupCity = 'Mumbai';
      try {
        final tripsController = Get.find<TripsController>();
        final trip = tripsController.allTrips.firstWhere((t) => t.id == tripId);
        pickupCity = trip.pickupCity;
      } catch (_) {}
      final startCoords = _getCoordinates(departureTitle.value, pickupCity);
      depLat = startCoords[0];
      depLng = startCoords[1];
    }
    
    simulatedLat = depLat;
    simulatedLng = depLng;

    _locationTimer?.cancel();
    // Save once immediately so the admin has a location the moment the trip
    // starts, then refresh every 10 minutes. This is deliberately NOT a
    // continuous live feed — periodic saves keep battery + Firestore writes low
    // while still letting the admin pull the latest position on demand.
    updateCurrentLocationDetails();
    _locationTimer = Timer.periodic(_locationSyncInterval, (timer) {
      if (isJourneyStarted.value && currentMilestone.value < 4) {
        updateCurrentLocationDetails();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> updateCurrentLocationDetails() async {
    try {
      final locationService = Get.find<LocationService>();
      final position = await locationService.getCurrentPosition();
      
      // Determine if we should simulate movement (i.e., we received fallback coordinates or are running in test emulator)
      if (position.latitude == LocationService.fallbackLatitude && 
          position.longitude == LocationService.fallbackLongitude) {
        isSimulatingMovement = true;
      }
      
      double currentLat = position.latitude;
      double currentLng = position.longitude;
      
      // Look up destination coordinates
      double destLat = 22.6208;
      double destLng = 75.8039;
      bool hasDestCoords = false;
      
      try {
        final tripsController = Get.find<TripsController>();
        final trip = tripsController.allTrips.firstWhere((t) => t.id == tripId);
        if (trip.dropLatitude != null && trip.dropLongitude != null) {
          destLat = trip.dropLatitude!;
          destLng = trip.dropLongitude!;
          hasDestCoords = true;
        }
      } catch (_) {}
      
      if (!hasDestCoords) {
        String dropCity = 'Indore';
        try {
          final tripsController = Get.find<TripsController>();
          final trip = tripsController.allTrips.firstWhere((t) => t.id == tripId);
          dropCity = trip.dropCity;
        } catch (_) {}
        final endCoords = _getCoordinates(destinationTitle.value, dropCity);
        destLat = endCoords[0];
        destLng = endCoords[1];
      }

      if (isSimulatingMovement) {
        // Incrementally move closer to destination coordinates by 3% each step
        simulatedLat = simulatedLat + (destLat - simulatedLat) * 0.03;
        simulatedLng = simulatedLng + (destLng - simulatedLng) * 0.03;
        currentLat = simulatedLat;
        currentLng = simulatedLng;
      }

      // Get full address
      final address = await locationService.getAddressFromCoordinates(currentLat, currentLng);
      currentAddress.value = address;
      
      // Calculate distance
      final distance = locationService.calculateDistance(
        currentLat,
        currentLng,
        destLat,
        destLng,
      );
      
      // Update remaining distance and ETA
      remainingDistance.value = '${distance.toStringAsFixed(1)} KM';
      estimatedTime.value = locationService.estimateTravelTime(distance);
      
      // Update speed with a realistic highway value or 0 if delivered
      if (currentMilestone.value >= 4) {
        speed.value = 0;
        remainingDistance.value = '0 KM';
        estimatedTime.value = 'Delivered';
      } else {
        speed.value = 55 + (currentLat * 10).toInt() % 15;
      }
      
      // Update last synced text
      final now = DateTime.now();
      lastSynced.value = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // Save live location and geocoded address directly to Firestore collections
      final firebaseService = Get.find<FirebaseService>();
      await firebaseService.updateTripLocation(
        tripId,
        currentLat,
        currentLng,
        address,
        remainingDistance: remainingDistance.value,
        estimatedTime: estimatedTime.value,
      );
      await firebaseService.updateDriverLocation(
        currentLat,
        currentLng,
        address,
      );

      // Update local state in TripsController
      try {
        final tripsController = Get.find<TripsController>();
        final updatedTrips = tripsController.allTrips.map((trip) {
          if (trip.id == tripId) {
            return trip.copyWith(
              remainingDistance: remainingDistance.value,
              estimatedTime: estimatedTime.value,
              currentAddress: address,
            );
          }
          return trip;
        }).toList();
        tripsController.allTrips.assignAll(updatedTrips);
      } catch (_) {}
    } catch (_) {}
  }

  /// Fetches the device's real GPS fix + reverse-geocoded address for milestone
  /// logging. Falls back to the last simulated position only if GPS fails, so
  /// logs never end up with 0.0 coordinates.
  Future<({double lat, double lng, String address})> _realFix() async {
    final locationService = Get.find<LocationService>();
    // Force check location permission and service
    await locationService.checkLocationAccess();

    try {
      final pos = await locationService.getCurrentPosition();
      final address = await locationService.getAddressFromCoordinates(
          pos.latitude, pos.longitude);
      currentAddress.value = address;
      return (lat: pos.latitude, lng: pos.longitude, address: address);
    } catch (_) {
      return (
        lat: simulatedLat,
        lng: simulatedLng,
        address: currentAddress.value == 'Locating...'
            ? departureTitle.value
            : currentAddress.value,
      );
    }
  }

  String get _driverName {
    try {
      return Get.find<SessionService>().name.value;
    } catch (_) {
      return '';
    }
  }



  // Update milestone checkpoint progress
  void selectMilestone(int milestoneIndex) {
    if (milestoneIndex < currentMilestone.value) {
      AppSnackBar.showInfo(
        title: 'Checkpoint Completed',
        message: 'This milestone has already been logged.',
      );
      return;
    }
    
    String milestoneName = '';
    if (milestoneIndex == 1) milestoneName = 'Reached Pickup';
    if (milestoneIndex == 2) milestoneName = 'Loaded';
    if (milestoneIndex == 3) milestoneName = 'Reached Drop';

    if (milestoneIndex == 3) {
      // Reached drop → upload Proof of Delivery, then request admin approval to
      // complete. The trip only becomes DELIVERED after the admin approves.
      Get.toNamed(Routes.PROOF_OF_DELIVERY, arguments: {'tripId': tripId})?.then((result) async {
        if (result == true) {
          String driverName = '';
          try {
            driverName = Get.find<SessionService>().name.value;
          } catch (_) {}
          AppPopup.showLoading(message: 'Verifying location & sending request...');
          try {
            final fix = await _realFix();
            final fb = Get.find<FirebaseService>();
            await fb.requestDelivery(
              tripId,
              location: fix.address,
              latitude: fix.lat,
              longitude: fix.lng,
              driverName: driverName,
            );
            AppPopup.hideLoading();
            AppSnackBar.showSuccess(
              title: 'Delivery Sent 📍',
              message: 'Admin ko approval ke liye bhej diya. Approve hone par '
                  'trip complete ho jayegi.',
            );
          } catch (e) {
            AppPopup.hideLoading();
            AppSnackBar.showError(
              title: 'Delivery Request Failed',
              message: 'Could not send request: ${e.toString()}',
            );
          }
        }
      });
      return;
    }

    AppPopup.showConfirmation(
      title: 'CONFIRM CHECKPOINT',
      description: 'Would you like to mark "$milestoneName" as completed?',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Verifying checkpoint location...');
        try {
          final fix = await _realFix();
          final firebaseService = Get.find<FirebaseService>();
          await firebaseService.updateTripMilestone(
            tripId,
            milestoneIndex + 1,
            locationName: fix.address,
            latitude: fix.lat,
            longitude: fix.lng,
          );
          currentMilestone.value = milestoneIndex + 1;
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
            title: 'Checkpoint Verified',
            message: 'Logged milestone: $milestoneName',
          );
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(
            title: 'Checkpoint Failed',
            message: 'Could not log checkpoint: ${e.toString()}',
          );
        }
      },
    );
  }

  @override
  void onClose() {
    _locationTimer?.cancel();
    _tripStatusSub?.cancel();
    _destReminderTimer?.cancel();
    super.onClose();
  }
}
