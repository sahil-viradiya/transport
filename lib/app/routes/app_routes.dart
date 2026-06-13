part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const SHOWCASE = _Paths.SHOWCASE;
  static const LOGIN = _Paths.LOGIN;
  static const DASHBOARD = _Paths.DASHBOARD;
  static const SPLASH = _Paths.SPLASH;
  static const OTP_VERIFICATION = _Paths.OTP_VERIFICATION;
  static const HOME = _Paths.HOME;
  static const TRIP_DETAILS = _Paths.TRIP_DETAILS;
  static const PROOF_OF_DELIVERY = _Paths.PROOF_OF_DELIVERY;
}

abstract class _Paths {
  _Paths._();
  static const SHOWCASE = '/showcase';
  static const LOGIN = '/login';
  static const DASHBOARD = '/dashboard';
  static const SPLASH = '/splash';
  static const OTP_VERIFICATION = '/otp-verification';
  static const HOME = '/home';
  static const TRIP_DETAILS = '/trip-details';
  static const PROOF_OF_DELIVERY = '/proof-of-delivery';
}
