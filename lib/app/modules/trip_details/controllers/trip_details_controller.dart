import 'dart:async';
import 'package:get/get.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/routes/app_pages.dart';
import '../../trips/controllers/trips_controller.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/location_service.dart';

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
  late String vehicleNo;
  late String consignmentNo;
  
  // Departure Info
  late String departureTitle;
  late String departureSubtitle;
  late String departureTime;

  // Destination Info
  late String destinationTitle;
  late String destinationSubtitle;

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
    vehicleNo = 'HR-22-9012';
    consignmentNo = '#9012';
    departureTitle = 'JNPT Port Terminal';
    departureSubtitle = 'Navi Mumbai, Maharashtra';
    departureTime = 'Today, 06:30 AM';
    destinationTitle = 'Indore Logistics Hub';
    destinationSubtitle = 'Pithampur, Madhya Pradesh';

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
      if (argTripId != null) {
        try {
          final tripsController = Get.find<TripsController>();
          final trip = tripsController.allTrips.firstWhere((t) => t.id == argTripId);
          tripId = trip.id;
          vehicleNo = trip.truckNo;
          
          final cleanIdDigits = trip.id.replaceAll(RegExp(r'\D'), '');
          consignmentNo = '#${cleanIdDigits.isNotEmpty ? cleanIdDigits : "9012"}';
          
          departureTitle = trip.pickupLocation;
          departureSubtitle = '${trip.pickupCity}, India';
          departureTime = trip.date;
          destinationTitle = trip.dropLocation;
          destinationSubtitle = '${trip.dropCity}, India';
          
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
      final startCoords = _getCoordinates(departureTitle, pickupCity);
      startLat = startCoords[0];
      startLng = startCoords[1];
      
      final endCoords = _getCoordinates(destinationTitle, dropCity);
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
      final startCoords = _getCoordinates(departureTitle, pickupCity);
      depLat = startCoords[0];
      depLng = startCoords[1];
    }
    
    simulatedLat = depLat;
    simulatedLng = depLng;

    _locationTimer?.cancel();
    updateCurrentLocationDetails();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
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
        final endCoords = _getCoordinates(destinationTitle, dropCity);
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
            return TripItemModel(
              id: trip.id,
              truckNo: trip.truckNo,
              status: trip.status,
              pickupCity: trip.pickupCity,
              pickupLocation: trip.pickupLocation,
              dropCity: trip.dropCity,
              dropLocation: trip.dropLocation,
              date: trip.date,
              tabType: trip.tabType,
              isActive: trip.isActive,
              remainingDistance: remainingDistance.value,
              estimatedTime: estimatedTime.value,
              currentAddress: address,
              driverPhone: trip.driverPhone,
            );
          }
          return trip;
        }).toList();
        tripsController.allTrips.assignAll(updatedTrips);
      } catch (_) {}
    } catch (_) {}
  }

  // Action to start the journey
  void startJourney() {
    final tripsController = Get.find<TripsController>();
    
    // Prevent starting/resuming a completed trip
    try {
      final trip = tripsController.allTrips.firstWhere((t) => t.id == tripId);
      if (trip.status == 'DELIVERED') {
        AppSnackBar.showError(
          title: 'Trip Completed',
          message: 'This trip is already completed and cannot be restarted.',
        );
        return;
      }
    } catch (_) {}

    final hasActiveTrip = tripsController.allTrips.any((t) => t.isActive && t.id != tripId);
    
    String descriptionText = 'Are you ready to initiate your trip $tripId and start GPS route sync?';
    if (hasActiveTrip) {
      final activeTrip = tripsController.allTrips.firstWhere((t) => t.isActive);
      descriptionText = 'Warning: Trip ${activeTrip.id} is currently active. Starting this journey will automatically suspend/deactivate it. Proceed?';
    }

    AppPopup.showConfirmation(
      title: 'START JOURNEY',
      description: descriptionText,
      confirmText: 'Start',
      cancelText: 'Cancel',
      onConfirm: () async {
        isJourneyStarted.value = true;
        currentMilestone.value = 2;
        startLocationUpdates();
        try {
          final firebaseService = Get.find<FirebaseService>();
          await firebaseService.updateTripMilestone(
            tripId, 
            2, 
            status: 'ACTIVE NOW',
            locationName: currentAddress.value == 'Locating...' ? departureTitle : currentAddress.value,
            latitude: simulatedLat,
            longitude: simulatedLng,
          );
          
          // Update local TripsController state so that only this trip is active
          final updatedTrips = tripsController.allTrips.map((trip) {
            if (trip.id == tripId) {
              return TripItemModel(
                id: trip.id,
                truckNo: trip.truckNo,
                status: 'ACTIVE NOW',
                pickupCity: trip.pickupCity,
                pickupLocation: trip.pickupLocation,
                dropCity: trip.dropCity,
                dropLocation: trip.dropLocation,
                date: trip.date,
                tabType: trip.tabType,
                isActive: true,
                driverPhone: trip.driverPhone,
              );
            } else {
              return TripItemModel(
                id: trip.id,
                truckNo: trip.truckNo,
                status: trip.status == 'ACTIVE NOW' ? 'ASSIGNED' : trip.status,
                pickupCity: trip.pickupCity,
                pickupLocation: trip.pickupLocation,
                dropCity: trip.dropCity,
                dropLocation: trip.dropLocation,
                date: trip.date,
                tabType: trip.tabType,
                isActive: false,
                driverPhone: trip.driverPhone,
              );
            }
          }).toList();
          tripsController.allTrips.assignAll(updatedTrips);
        } catch (_) {}
        AppSnackBar.showSuccess(
          title: 'Journey Started',
          message: 'GPS tracking is now active. Drive safely!',
        );
      },
    );
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
      // Reaching the drop point triggers the Proof of Delivery flow
      Get.toNamed(Routes.PROOF_OF_DELIVERY, arguments: {'tripId': tripId})?.then((result) async {
        if (result == true) {
          currentMilestone.value = 4;
          remainingDistance.value = '0 KM';
          speed.value = 0;
          estimatedTime.value = 'Delivered';
          _locationTimer?.cancel();

          // Automatically return to the Home/Dashboard screen after showing the completed state for a brief moment
          await Future.delayed(const Duration(milliseconds: 1500));
          Get.back();
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
        currentMilestone.value = milestoneIndex + 1;
        try {
          final firebaseService = Get.find<FirebaseService>();
          await firebaseService.updateTripMilestone(
            tripId, 
            milestoneIndex + 1,
            locationName: currentAddress.value == 'Locating...' ? departureTitle : currentAddress.value,
            latitude: simulatedLat,
            longitude: simulatedLng,
          );
        } catch (_) {}
        AppSnackBar.showSuccess(
          title: 'Checkpoint Verified',
          message: 'Logged milestone: $milestoneName',
        );
      },
    );
  }

  @override
  void onClose() {
    _locationTimer?.cancel();
    super.onClose();
  }
}
