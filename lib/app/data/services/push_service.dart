import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'firebase_service.dart';
import 'session_service.dart';
import 'web_notify.dart' as web_notify;
import '../../routes/app_pages.dart';
import '../../../widgets/dialogs/app_snackbar.dart';

/// Background / terminated messages. Firebase must be re-initialised in this
/// isolate. The OS auto-displays the `notification` payload, so we only need a
/// top-level handler to exist.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging — turns every in-app notification into a real push
/// (foreground + background + terminated) and routes taps to the right screen.
///
/// - Foreground: shows a heads-up banner (flutter_local_notifications on
///   Android, presentation options on iOS) + an in-app snackbar.
/// - Background / terminated: the OS shows the `notification` payload; tapping it
///   opens the app and navigates (onMessageOpenedApp / getInitialMessage).
/// - Saves the device token to `users/{phone}.fcmTokens` for the Cloud Function.
///
/// Defensive everywhere: if FCM isn't configured (desktop, or web without a
/// VAPID key) it degrades to a no-op and the in-app bell still works.
class PushService extends GetxService {
  // Web push VAPID key — Firebase Console → Project Settings → Cloud Messaging
  // → Web Push certificates → Key pair.
  static const String webVapidKey =
      'BKAXZv30eXYX4THvhtZZYNECNa7Qn0ykBga_IyJ1SP6CimbAQmujWD5u2D4Gn3AxFek05ULdpCpPqFQ4wEoSgdA';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  final _channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Trip, expense and driver notifications.',
    importance: Importance.max,
  );

  Future<PushService> init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!kIsWeb) {
        final android = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(_channel);
        // Android 13+ needs an explicit runtime notification permission.
        await android?.requestNotificationsPermission();

        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );
        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (resp) {
            final payload = resp.payload;
            if (payload != null && payload.isNotEmpty) {
              try {
                _navigate(Map<String, dynamic>.from(jsonDecode(payload)));
              } catch (_) {}
            }
          },
        );
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground message → heads-up banner (mobile) + snackbar + browser notification (web).
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          _localNotifications.show(
            id: msg.hashCode,
            title: n.title,
            body: n.body,
            payload: jsonEncode(msg.data),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }

        // Show a native browser notification on web (foreground messages are
        // not auto-displayed by the browser; the service worker only handles
        // background/terminated state).
        if (kIsWeb) {
          web_notify.showBrowserNotification(
            n.title ?? 'Notification',
            n.body ?? '',
          );
        }

        AppSnackBar.showInfo(
          title: n.title ?? 'Notification',
          message: n.body ?? '',
        );
      });

      // Tap on a background notification → open its detail page.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _navigate(m.data));

      // Cold start from a terminated notification → navigate once the app is up.
      final initial = await messaging.getInitialMessage();
      if (initial != null && initial.data.isNotEmpty) {
        final data = Map<String, dynamic>.from(initial.data);
        Future.delayed(const Duration(seconds: 3), () => _navigate(data));
      }

      messaging.onTokenRefresh.listen(_saveToken);

      await registerForUser();
      try {
        final session = Get.find<SessionService>();
        ever(session.phone, (_) => registerForUser());
      } catch (_) {}
    } catch (e) {
      debugPrint('PushService init skipped (FCM not available here): $e');
    }
    return this;
  }

  void _navigate(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    try {
      Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: data);
    } catch (_) {}
  }

  /// Current browser notification permission on web ('granted' / 'denied' /
  /// 'default' / 'unsupported'). Always 'granted' on mobile — the OS-level
  /// heads-up there is handled by flutter_local_notifications, not this API.
  String get webNotificationPermission =>
      kIsWeb ? web_notify.notificationPermission : 'granted';

  /// Explicitly (re)requests notification permission. Call this from a real
  /// user tap (e.g. an "Enable Notifications" button) — browsers are far more
  /// reliable about actually showing the prompt when it's tied to a genuine
  /// gesture rather than the automatic request at app boot, which some
  /// browsers silently ignore. Returns true if permission ends up granted.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) {
      final result = await web_notify.requestNotificationPermission();
      return result == 'granted';
    }
    try {
      final settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Show a native browser notification (web) or OS heads-up (mobile/Android).
  /// Called by [NotificationsController] whenever a new notification arrives on
  /// the recipient's live Firestore stream.
  Future<void> showLocal(String title, String body, {String? payload}) async {
    // Web: use the browser Notification API directly.
    if (kIsWeb) {
      web_notify.showBrowserNotification(title, body);
      return;
    }
    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  /// Associate this device's token with the signed-in user.
  Future<void> registerForUser() async {
    try {
      final phone = Get.find<SessionService>().ownerKey;
      if (phone.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb && webVapidKey.isNotEmpty ? webVapidKey : null,
      );
      if (token != null) await _saveToken(token);
    } catch (_) {}
  }

  Future<void> _saveToken(String token) async {
    try {
      final phone = Get.find<SessionService>().ownerKey;
      if (phone.isEmpty) return;
      await Get.find<FirebaseService>().saveFcmToken(phone, token);
    } catch (_) {}
  }
}
