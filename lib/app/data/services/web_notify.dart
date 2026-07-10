// Conditional import shim — selects the correct implementation at compile time.
// On web (dart:js_interop available) → web_notify_impl.dart (browser Notification API).
// On all other platforms            → web_notify_stub.dart (no-op).
export 'web_notify_stub.dart'
    if (dart.library.js_interop) 'web_notify_impl.dart';
