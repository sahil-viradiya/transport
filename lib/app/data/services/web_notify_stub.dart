// Web notification stub for non-web platforms.
// On Android/iOS, push_service.dart uses flutter_local_notifications directly.
void showBrowserNotification(String title, String body) {
  // no-op on non-web platforms
}

/// Non-web platforms manage notification permission via the OS, not this API.
String get notificationPermission => 'granted';

Future<String> requestNotificationPermission() async => 'granted';
