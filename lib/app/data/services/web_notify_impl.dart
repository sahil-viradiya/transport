// Web-only implementation using dart:js_interop.
// This file is only compiled when targeting the web platform.
import 'dart:js_interop';

@JS('Notification')
extension type _BrowserNotification._(JSObject _) implements JSObject {
  external factory _BrowserNotification(String title, JSObject options);

  @JS('permission')
  external static String get permission;

  @JS('requestPermission')
  external static JSPromise<JSString> requestPermission();
}

/// Shows a native OS browser notification. Silently fails if permission
/// was not granted (the FCM permission request handles that earlier).
void showBrowserNotification(String title, String body) {
  try {
    if (_BrowserNotification.permission != 'granted') return;
    final options = {
      'body': body,
      'icon': '/icons/Icon-192.png',
    }.jsify()! as JSObject;
    _BrowserNotification(title, options);
  } catch (_) {}
}

/// Current browser permission: 'granted' | 'denied' | 'default', or
/// 'unsupported' if the Notification API itself isn't available.
String get notificationPermission {
  try {
    return _BrowserNotification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// Explicitly asks the browser for notification permission. Browsers are far
/// more reliable about actually showing the prompt (rather than silently
/// leaving it at 'default') when this is called from a real user gesture —
/// e.g. an "Enable Notifications" button tap — rather than automatically at
/// app boot. Returns the resulting permission string.
Future<String> requestNotificationPermission() async {
  try {
    final result = await _BrowserNotification.requestPermission().toDart;
    return result.toDart;
  } catch (_) {
    return 'denied';
  }
}
