import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:transport/app/core/theme/app_theme.dart';
import 'package:transport/app/core/translations/app_translations.dart';
import 'package:transport/app/routes/app_pages.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/data/services/connectivity_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/premium_widgets.dart';
import 'package:transport/widgets/trip_progress_tracker.dart';
import 'package:transport/app/modules/login/controllers/login_controller.dart';
import 'package:transport/app/modules/login/views/login_view.dart';
import 'package:transport/app/modules/splash/controllers/splash_controller.dart';
import 'package:transport/app/modules/splash/views/splash_view.dart';
import 'package:transport/app/modules/home/controllers/home_controller.dart';
import 'package:transport/app/modules/trips/controllers/trips_controller.dart';
import 'package:transport/app/modules/trips/views/trips_view.dart';
import 'package:transport/app/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:transport/app/modules/dashboard/views/dashboard_view.dart';
import 'package:transport/app/modules/admin_home/controllers/admin_home_controller.dart';
import 'package:transport/app/modules/admin_home/views/admin_home_view.dart';
import 'package:transport/app/data/notifications_controller.dart';
import 'package:transport/app/modules/notification_detail/views/notification_detail_view.dart';
import 'package:transport/app/modules/notification_detail/bindings/notification_detail_binding.dart';
import 'package:transport/app/modules/active_drivers/views/active_drivers_view.dart';
import 'package:transport/app/modules/driver_detail/views/driver_detail_view.dart';
import 'package:transport/app/modules/driver_detail/bindings/driver_detail_binding.dart';
import 'package:transport/app/modules/inspection/views/inspection_view.dart';

/// Connectivity stub that reports "online" without touching the platform.
class _OnlineConnectivity extends ConnectivityService {
  @override
  Future<ConnectivityService> init() async {
    isConnected.value = true;
    return this;
  }
}

Widget _app(Widget home, {List<GetPage>? pages}) => GetMaterialApp(
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      home: home,
      getPages: pages,
    );

// Small phone to stress horizontal layouts the hardest.
const _phone = Size(360, 690);

void main() {
  setUpAll(() {
    // Never hit the network for fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'userPhone': '919876543210',
      'userRole': 'owner',
      'userName': 'Rajeshbhai Patel',
    });
  });

  tearDown(Get.reset);

  testWidgets('Login screen renders without overflow', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    Get.put(SessionService(storage: storage));
    Get.put(LoginController());

    await tester.pumpWidget(_app(const LoginView()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('Splash screen renders without overflow', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    Get.put<SessionService>(session);
    Get.put(SplashController());

    // Stub routes so the splash's post-load navigation has somewhere to go.
    final stubs = [
      GetPage(name: Routes.HOME, page: () => const Scaffold()),
      GetPage(name: Routes.LOGIN, page: () => const Scaffold()),
      GetPage(name: Routes.ADMIN_HOME, page: () => const Scaffold()),
    ];

    await tester.pumpWidget(_app(const SplashView(), pages: stubs));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('journey_partner'.tr), findsOneWidget);

    // Drain the 3s splash timer so no pending timer fails the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('HeroStat clips a long vehicle number instead of overflowing',
      (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 150,
            child: HeroStat(
              icon: Icons.local_shipping_rounded,
              label: 'Vehicle',
              value: 'GJ-01-AB-1234-EXTRA-LONG',
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TripProgressTracker renders in a narrow card without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final trip = {
      'currentMilestone': 3,
      'status': 'ACTIVE NOW',
      'dropCity': 'Indore',
      'pickupLocation': 'Aslali Transport Nagar',
      'dropLocation': 'Pithampur Industrial Hub',
      'milestonesLog': [
        {
          'milestone': 2,
          'label': 'Reached Pickup',
          'address': 'Aslali Transport Nagar, Ahmedabad',
          'timestamp': '2026-06-23 09:00',
        },
      ],
    };

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TripProgressTracker(trip: trip),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Delivered'), findsOneWidget); // stage label present
  });

  testWidgets('A delivered trip shows all 4 stages ticked (no amber truck)',
      (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final trip = {
      'status': 'DELIVERED',
      'currentMilestone': 4,
      'dropLocation': 'Mavdi Chowkdi',
      'milestonesLog': [
        {'milestone': 4, 'label': 'Delivered', 'address': 'Mavdi Chowkdi', 'timestamp': '11:09'},
      ],
    };

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TripProgressTracker(trip: trip, showSummary: false),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // All four nodes are completed ticks; the amber "currently here" truck is gone.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.local_shipping_rounded), findsNothing);
  });

  testWidgets('Dashboard renders an active trip without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(
        phone: '919876543210', name: 'Rajeshbhai Patel Transport', role: 'owner');
    Get.put<SessionService>(session);
    await Get.putAsync<ConnectivityService>(() => _OnlineConnectivity().init());

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('919876543210').set(
        {'name': 'Rajeshbhai Patel Transport', 'avatarUrl': ''});
    await firestore.collection('trips').doc('TRP-1').set({
      'truckNo': 'GJ-01-AB-1234',
      'ownerId': '919876543210',
      'driverPhone': '919876543210',
      'status': 'ACTIVE NOW',
      'isActive': true,
      'currentMilestone': 3,
      'pickupCity': 'Ahmedabad',
      'dropCity': 'Indore',
      'pickupLocation': 'Aslali Transport Nagar',
      'dropLocation': 'Pithampur Hub',
      'milestonesLog': [
        {'milestone': 2, 'label': 'Reached Pickup', 'address': 'Aslali', 'timestamp': '09:00'},
      ],
    });
    await firestore.collection('trucks').doc('t1').set(
        {'truckNo': 'GJ-01-AB-1234', 'model': 'Tata Signa 5530.S', 'ownerId': '919876543210'});

    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919876543210'));
    Get.put(HomeController());
    Get.put(TripsController());
    Get.put(DashboardController());
    Get.put(NotificationsController());

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const DashboardView()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });

    expect(tester.takeException(), isNull);
    // Reference dashboard: My Truck card + driver name render.
    expect(find.text('My Truck'), findsOneWidget);
    expect(find.textContaining('Rajeshbhai'), findsOneWidget);
  });

  testWidgets('Inspection tab shows pending truck with Start Inspection',
      (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(
        phone: '919876543210', name: 'Rajesh', role: 'owner');
    Get.put<SessionService>(session);
    await Get.putAsync<ConnectivityService>(() => _OnlineConnectivity().init());

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('trucks').doc('GJ-01').set({
      'truckNo': 'GJ-01',
      'assignedTo': '919876543210',
      'inspectionStatus': 'pending',
    });
    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919876543210'));
    Get.put(HomeController());
    Get.put(TripsController());
    Get.put(DashboardController());
    Get.put(NotificationsController());

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const InspectionView()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Start Inspection'), findsOneWidget);
  });

  Future<void> setUpAdmin() async {
    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(phone: '919999999999', role: 'admin', name: 'Admin');
    Get.put<SessionService>(session);
    await Get.putAsync<ConnectivityService>(() => _OnlineConnectivity().init());

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('919876543210').set(
        {'name': 'Rajesh Kumar', 'phone': '919876543210', 'role': 'driver'});
    for (final id in ['123', '222']) {
      await firestore.collection('trips').doc(id).set({
        'truckNo': 'MH-12-BV-0045',
        'ownerId': '919876543210',
        'driverPhone': '919876543210',
        'status': 'DELIVERED',
        'isActive': false,
        'currentMilestone': 4,
        'pickupCity': 'Surat',
        'dropCity': 'Rajkot',
        'pickupLocation': 'Yogi Chowk',
        'dropLocation': 'Mavdi Chowkdi',
        'date': '19 Jun, 11:09 AM',
        'milestonesLog': [
          {'milestone': 2, 'label': 'Reached Pickup', 'address': 'Yogi Chowk', 'timestamp': '11:10', 'latitude': 21.21476, 'longitude': 72.88869},
          {'milestone': 3, 'label': 'Loaded', 'address': '76PW+8XH, Kendranagar, Vadodara, Gujarat, 390025', 'timestamp': '11:10', 'latitude': 21.21476, 'longitude': 72.88869},
          {'milestone': 4, 'label': 'Reached Drop / Delivered', 'address': 'SF 127, Shri SIDDHESHWAR THE BUSINESS HARBOUR NARAYAN VIDHYALAY ROAD, Kendranagar, Vadodara', 'timestamp': '11:11', 'latitude': 22.28506, 'longitude': 73.24735},
        ],
      });
    }
    await firestore.collection('trucks').doc('t1').set(
        {'truckNo': 'MH-12-BV-0045', 'model': 'Tata Signa', 'ownerId': '919876543210'});

    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919999999999'));
    Get.put(NotificationsController());
    Get.put(AdminHomeController());
  }

  testWidgets('Admin panel renders the Trips tab on mobile without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await setUpAdmin();
    Get.find<AdminHomeController>().currentTabIndex.value = 1;

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const AdminHomeView()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Highway Terminal Admin'), findsOneWidget);
  });

  testWidgets('Admin back press returns to Dashboard tab, then double-back hint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await setUpAdmin();
    final c = Get.find<AdminHomeController>();
    c.currentTabIndex.value = 2; // Trucks tab

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const AdminHomeView()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });

    // First back: non-home tab → jumps to Dashboard, app stays open.
    c.handleBackPress();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.currentTabIndex.value, 0);

    // Next back on Dashboard: shows the "press again to exit" hint.
    c.handleBackPress();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Exit App'), findsOneWidget);

    // Drain the snackbar so no pending timers fail the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Admin panel renders on web/desktop (wide) without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(tester.view.reset);

    await setUpAdmin();
    Get.find<AdminHomeController>().currentTabIndex.value = 1;

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const AdminHomeView()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    // Wide layout shows the dark brand sidebar + top bar instead of bottom nav.
    expect(find.text('BHARAT'), findsOneWidget);
    expect(find.text('Add New'), findsOneWidget);
  });

  testWidgets('Trip details page renders long-address milestones without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(tester.view.reset);

    await setUpAdmin();
    Get.find<AdminHomeController>().currentTabIndex.value = 1;

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const AdminHomeView()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      // The trip card opens the audit via its "View Details" action (the old
      // eye-icon button was replaced by this in the card redesign).
      await tester.tap(find.text('View Details').first);
      await tester.pumpAndSettle();
    });

    expect(tester.takeException(), isNull);
    expect(find.text('JOURNEY MILESTONES AUDIT'), findsOneWidget);
  });

  testWidgets('Notification detail page shows Approve/Reject for a load request',
      (tester) async {
    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(phone: '919999999999', role: 'admin', name: 'Admin');
    Get.put<SessionService>(session);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('trips').doc('TRP-1').set({
      'status': 'LOAD_REQUESTED',
      'pickupCity': 'Surat',
      'dropCity': 'Rajkot',
      'currentMilestone': 3,
      'ownerId': '919876543210',
      'driverPhone': '919876543210',
    });
    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919999999999'));

    await tester.pumpWidget(_app(
      const Scaffold(),
      pages: [
        GetPage(
          name: Routes.NOTIFICATION_DETAIL,
          page: () => const NotificationDetailView(),
          binding: NotificationDetailBinding(),
        ),
      ],
    ));
    Get.toNamed(Routes.NOTIFICATION_DETAIL,
        arguments: {'type': 'load_request', 'tripId': 'TRP-1', 'id': 'n1'});
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('Notification detail renders a non-actionable note without Obx error',
      (tester) async {
    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    Get.put<SessionService>(session);
    Get.put(FirebaseService(
        firestore: FakeFirebaseFirestore(),
        ownerKeyResolver: () => '919876543210'));

    await tester.pumpWidget(_app(
      const Scaffold(),
      pages: [
        GetPage(
          name: Routes.NOTIFICATION_DETAIL,
          page: () => const NotificationDetailView(),
          binding: NotificationDetailBinding(),
        ),
      ],
    ));
    // Informational notification: no tripId, no action available.
    Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: {
      'type': 'check_in',
      'title': 'Driver On Duty',
      'body': 'Rajesh is available.',
      'id': 'n2',
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('No action needed'), findsOneWidget);
  });

  testWidgets('Trips card renders priority + long status + long truck without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(
        phone: '919876543210', name: 'Rajesh', role: 'owner');
    Get.put<SessionService>(session);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('trips').doc('TRP-LONG').set({
      'ownerId': '919876543210',
      'driverPhone': '919876543210',
      'truckNo': 'GJ-01-AB-1234-XY',
      'status': 'DELIVERY_REQUESTED',
      'priority': true,
      'tabType': 'Today',
      'pickupCity': 'Ahmedabad',
      'dropCity': 'Surat',
      'pickupLocation': 'Aslali',
      'dropLocation': 'Sachin',
      'date': 'Today',
    });
    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919876543210'));
    Get.put(TripsController());

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const TripsView()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    expect(find.text('PRIORITY'), findsOneWidget);
  });

  testWidgets('Active Drivers list shows an on-duty driver', (tester) async {
    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(phone: '919999999999', role: 'admin', name: 'Admin');
    Get.put<SessionService>(session);
    await Get.putAsync<ConnectivityService>(() => _OnlineConnectivity().init());

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('919876543210').set({
      'name': 'Rajesh Kumar',
      'phone': '919876543210',
      'role': 'driver',
      'availability': 'available',
      'checkInAddress': 'Surat Depot',
    });
    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919999999999'));
    Get.put(AdminHomeController());

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const Scaffold(), pages: [
        GetPage(
            name: Routes.ACTIVE_DRIVERS,
            page: () => const ActiveDriversView()),
      ]));
      Get.toNamed(Routes.ACTIVE_DRIVERS);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Rajesh Kumar'), findsOneWidget);
  });

  testWidgets('Driver detail page shows the profile + vehicle', (tester) async {
    final storage = await StorageService().init();
    Get.put<StorageService>(storage);
    final session = SessionService(storage: storage);
    await session.init();
    Get.put<SessionService>(session);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('919876543210').set({
      'name': 'Rajesh Kumar',
      'phone': '919876543210',
      'role': 'driver',
      'availability': 'available',
    });
    await firestore.collection('drivers').doc('919876543210').set({
      'vehicleNo': 'GJ-01-AB-1234',
      'vehicleModel': 'Tata Signa',
    });
    Get.put(FirebaseService(
        firestore: firestore, ownerKeyResolver: () => '919876543210'));

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_app(const Scaffold(), pages: [
        GetPage(
            name: Routes.DRIVER_DETAIL,
            page: () => const DriverDetailView(),
            binding: DriverDetailBinding()),
      ]));
      Get.toNamed(Routes.DRIVER_DETAIL, arguments: {'phone': '919876543210'});
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('GJ-01-AB-1234'), findsOneWidget);
  });
}
