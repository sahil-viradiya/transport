import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'firebase_service.dart';
import 'session_service.dart';
import 'web_notify.dart' as web_notify;
import '../../routes/app_pages.dart';
import '../../../widgets/dialogs/app_snackbar.dart';

/// Top-level background / terminated FCM message handler.
/// Executed in a separate background isolate when the application is terminated or in background.
/// Must be annotated with `@pragma('vm:entry-point')` and initialize Firebase.
///
/// NOTE: For messages with a `notification` payload, Android/iOS native FCM SDK automatically
/// displays the heads-up notification banner in background/terminated state. We only trigger
/// `FlutterLocalNotificationsPlugin.show()` for `data`-only payloads to avoid duplicate notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCFte8SaEM25uQNis6B7-Ls0T3nE9uN7W0",
          authDomain: "transport-1faf4.firebaseapp.com",
          projectId: "transport-1faf4",
          storageBucket: "transport-1faf4.firebasestorage.app",
          messagingSenderId: "1048359203148",
          appId: "1:1048359203148:web:5e3d6694adb35a22765fe9",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  }

  // Handle data-only messages in background/terminated state (where FCM native SDK does not auto-display).
  if (!kIsWeb && message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const channelV2 = AndroidNotificationChannel(
      'high_importance_channel_v2',
      'High Importance Notifications',
      description: 'Trip, expense and driver notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channelV2);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await localNotifications.initialize(settings: initSettings);

    final title = message.data['title']?.toString() ??
        message.data['type']?.toString() ??
        'Notification';
    final body = message.data['body']?.toString() ?? '';

    if (title.isNotEmpty || body.isNotEmpty) {
      await localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        payload: jsonEncode(message.data),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelV2.id,
            channelV2.name,
            channelDescription: channelV2.description,
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
            ticker: title,
            category: AndroidNotificationCategory.message,
            audioAttributesUsage: AudioAttributesUsage.notification,
            styleInformation: BigTextStyleInformation(body),
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  debugPrint('[FCM Background Isolate] Handled background message: ${message.messageId}');
}

/// Firebase Cloud Messaging — turns every in-app notification into a real push
/// (foreground + background + terminated) and routes taps to the right screen.
class PushService extends GetxService {
  static const String webVapidKey =
      'BKAXZv30eXYX4THvhtZZYNECNa7Qn0ykBga_IyJ1SP6CimbAQmujWD5u2D4Gn3AxFek05ULdpCpPqFQ4wEoSgdA';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  final _channelV2 = const AndroidNotificationChannel(
    'high_importance_channel_v2',
    'High Importance Notifications',
    description: 'Trip, expense and driver notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final _channelV1 = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications Legacy',
    description: 'Trip, expense and driver notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<PushService> init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!kIsWeb) {
        final android = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(_channelV2);
        await android?.createNotificationChannel(_channelV1);
        await android?.requestNotificationsPermission();

        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
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

      // Foreground message listener
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
                _channelV2.id,
                _channelV2.name,
                channelDescription: _channelV2.description,
                importance: Importance.max,
                priority: Priority.high,
                visibility: NotificationVisibility.public,
                icon: '@mipmap/ic_launcher',
                ticker: n.title,
                category: AndroidNotificationCategory.message,
                audioAttributesUsage: AudioAttributesUsage.notification,
                styleInformation: BigTextStyleInformation(n.body ?? ''),
                fullScreenIntent: true,
              ),
            ),
          );
        }

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

      // Tap on background notification -> navigate
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _navigate(m.data));

      // Cold start from terminated notification -> navigate once the app is up
      final initial = await messaging.getInitialMessage();
      if (initial != null && initial.data.isNotEmpty) {
        final data = Map<String, dynamic>.from(initial.data);
        Future.delayed(const Duration(seconds: 2), () => _navigate(data));
      }

      messaging.onTokenRefresh.listen(_saveToken);

      await registerForUser();
      try {
        final session = Get.find<SessionService>();
        ever(session.phone, (_) => registerForUser());
      } catch (_) {}
    } catch (e) {
      debugPrint('PushService init warning: $e');
    }
    return this;
  }

  void _navigate(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    try {
      Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: data);
    } catch (_) {}
  }

  String get webNotificationPermission =>
      kIsWeb ? web_notify.notificationPermission : 'granted';

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

  void showWebBrowserNotification(String title, String body) {
    if (kIsWeb) web_notify.showBrowserNotification(title, body);
  }

  Future<void> showLocal(String title, String body, {String? payload}) async {
    if (kIsWeb) {
      web_notify.showBrowserNotification(title, body);
      AppSnackBar.showInfo(
        title: title,
        message: body,
      );
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
            _channelV2.id,
            _channelV2.name,
            channelDescription: _channelV2.description,
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
            ticker: title,
            category: AndroidNotificationCategory.message,
            audioAttributesUsage: AudioAttributesUsage.notification,
            styleInformation: BigTextStyleInformation(body),
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

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
