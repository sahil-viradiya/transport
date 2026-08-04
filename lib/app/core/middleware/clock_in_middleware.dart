import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/clock_in_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/routes/app_pages.dart';

/// Middleware that enforces driver clock-in duty state before accessing
/// protected driver activities (Home, Trips, POD, Expenses, etc.).
class ClockInMiddleware extends GetMiddleware {
  @override
  int? get priority => 2; // Executes after AuthMiddleware (priority 1)

  @override
  RouteSettings? redirect(String? route) {
    try {
      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        // Admins are exempt from driver shift clock-in checks
        if (session.isAdmin) {
          return null;
        }
      }

      if (Get.isRegistered<ClockInService>()) {
        final clockInService = Get.find<ClockInService>();
        final initialRoute = clockInService.getInitialRoute();
        
        if (initialRoute != Routes.HOME && route != initialRoute) {
          debugPrint('[ClockInMiddleware] Redirecting from $route to $initialRoute');
          return RouteSettings(name: initialRoute);
        }
      }
    } catch (e) {
      debugPrint('[ClockInMiddleware] Exception checking shift status: $e');
    }
    return null;
  }
}
