// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';
import '../modules/showcase/bindings/showcase_binding.dart';
import '../modules/showcase/views/showcase_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/otp_verification/bindings/otp_verification_binding.dart';
import '../modules/otp_verification/views/otp_verification_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/trip_details/bindings/trip_details_binding.dart';
import '../modules/trip_details/views/trip_status_view.dart';
import '../modules/proof_of_delivery/bindings/proof_of_delivery_binding.dart';
import '../modules/proof_of_delivery/views/proof_of_delivery_view.dart';
import '../modules/admin_home/bindings/admin_home_binding.dart';
import '../modules/admin_home/views/admin_home_view.dart';
import '../modules/notification_detail/bindings/notification_detail_binding.dart';
import '../modules/notification_detail/views/notification_detail_view.dart';
import '../modules/active_drivers/views/active_drivers_view.dart';
import '../modules/driver_detail/bindings/driver_detail_binding.dart';
import '../modules/driver_detail/views/driver_detail_view.dart';
import '../modules/expense_detail/bindings/expense_detail_binding.dart';
import '../modules/expense_detail/views/expense_detail_view.dart';
import '../modules/notification_permission/bindings/notification_permission_binding.dart';
import '../modules/notification_permission/views/notification_permission_view.dart';
import '../modules/location_permission/bindings/location_permission_binding.dart';
import '../modules/location_permission/views/location_permission_view.dart';
import '../modules/clock_in/bindings/clock_in_binding.dart';
import '../modules/clock_in/views/clock_in_view.dart';
import '../core/middleware/auth_middleware.dart';
import '../core/middleware/clock_in_middleware.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SHOWCASE,
      page: () => const ShowcaseView(),
      binding: ShowcaseBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.DASHBOARD,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.OTP_VERIFICATION,
      page: () => const OtpVerificationView(),
      binding: OtpVerificationBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware(), ClockInMiddleware()],
    ),
    GetPage(
      name: _Paths.TRIP_DETAILS,
      page: () => const TripStatusView(),
      binding: TripDetailsBinding(),
      middlewares: [AuthMiddleware(), ClockInMiddleware()],
    ),
    GetPage(
      name: _Paths.PROOF_OF_DELIVERY,
      page: () => const ProofOfDeliveryView(),
      binding: ProofOfDeliveryBinding(),
      middlewares: [AuthMiddleware(), ClockInMiddleware()],
    ),
    GetPage(
      name: _Paths.ADMIN_HOME,
      page: () => const AdminHomeView(),
      binding: AdminHomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.NOTIFICATION_DETAIL,
      page: () => const NotificationDetailView(),
      binding: NotificationDetailBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.ACTIVE_DRIVERS,
      page: () => const ActiveDriversView(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.DRIVER_DETAIL,
      page: () => const DriverDetailView(),
      binding: DriverDetailBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.EXPENSE_DETAIL,
      page: () => const ExpenseDetailView(),
      binding: ExpenseDetailBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.NOTIFICATION_PERMISSION,
      page: () => const NotificationPermissionView(),
      binding: NotificationPermissionBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.LOCATION_PERMISSION,
      page: () => const LocationPermissionView(),
      binding: LocationPermissionBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.CLOCK_IN,
      page: () => const ClockInView(),
      binding: ClockInBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
