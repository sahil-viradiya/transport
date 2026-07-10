// Web-only implementation using dart:js_interop.
// This file is only compiled when targeting the web platform.
import 'dart:js_interop';

@JS('Notification')
extension type _BrowserNotification._(JSObject _) implements JSObject {
  external factory _BrowserNotification(String title, JSObject options);

  @JS('permission')
  external static String get permission;
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
