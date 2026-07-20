import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/auth_service.dart';
import 'package:transport/app/routes/app_pages.dart';

/// Route guard that prevents unauthenticated users from reaching protected
/// screens (Home, Admin, Trip Details, etc.).
///
/// Attach this middleware to any [GetPage] that requires a valid Firebase Auth
/// session. If the user's session has expired or they haven't logged in, the
/// middleware redirects to the Login screen.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    try {
      final auth = Get.find<AuthService>();
      if (!auth.isAuthenticated) {
        debugPrint('[AuthMiddleware] Blocked unauthenticated access to $route');
        return const RouteSettings(name: Routes.LOGIN);
      }
    } catch (_) {
      // AuthService not registered yet (shouldn't happen, but be safe).
      return const RouteSettings(name: Routes.LOGIN);
    }
    return null; // Allow navigation
  }
}
