import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app/core/config/app_config.dart';
import 'app/core/translations/app_translations.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/services/storage_service.dart';
import 'app/data/services/secure_storage_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/data/services/firebase_service.dart';
import 'app/data/services/session_service.dart';
import 'app/data/services/auth_service.dart';
import 'app/data/services/push_service.dart';
import 'app/data/notifications_controller.dart';
import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register FCM background message handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await initServices();
  runApp(const MyApp());
}

Future<void> initServices() async {
  debugPrint('Initializing critical GetX services...');
  
  // Initialize Shared Preferences Storage & Global Configuration first
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => SecureStorageService().init());
  AppConfig.init();

  // Initialize Firebase Core
  try {
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

      // Activate App Check ONLY in Release builds to avoid blocking local Debug mode
      if (kReleaseMode && !AppConfig.isMock) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }
    }
    // Set locale to suppress "X-Firebase-Locale was null" warning
    FirebaseAuth.instance.setLanguageCode('en');
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  // Initialize Live Connectivity Checker
  await Get.putAsync(() => ConnectivityService().init());
  // Initialize Session (current logged-in owner identity) — depends on storage
  await Get.putAsync(() => SessionService().init());
  // Auth state listener (sign-out / token-revocation auto-redirect)
  await Get.putAsync(() => AuthService().init());
  // Initialize Firebase Service (Firestore CRUD) — resolves owner via session
  await Get.putAsync(() => FirebaseService().init());
  // App-wide notifications feed (bell badge for driver + admin)
  Get.put(NotificationsController(), permanent: true);
  // FCM push (permission, token save, foreground handler) — degrades to no-op
  // where FCM isn't configured, so it never blocks startup.
  await Get.putAsync(() => PushService().init());
  debugPrint('All services successfully registered.');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      onGenerateTitle: (context) => 'app_title'.tr,
      debugShowCheckedModeBanner: false,

      // Internationalization & Localization
      translations: AppTranslations(),
      locale: AppConfig.currentLocale.value,
      fallbackLocale: const Locale('en', 'US'),

      // Themes Setup matching guidelines
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // Routes Setup
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,

      // Smoother, consistent screen-to-screen transitions app-wide.
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 260),
    );
  }
}
