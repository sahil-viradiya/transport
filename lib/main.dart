import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/services/storage_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/data/services/firebase_service.dart';
import 'app/data/services/session_service.dart';
import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServices();
  runApp(const MyApp());
}

Future<void> initServices() async {
  debugPrint('Initializing critical GetX services...');
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
    }
    // Set locale to suppress "X-Firebase-Locale was null" warning
    FirebaseAuth.instance.setLanguageCode('en');
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('App running in Mock Mode.');
  }

  // Initialize Shared Preferences Storage
  await Get.putAsync(() => StorageService().init());
  // Initialize Live Connectivity Checker
  await Get.putAsync(() => ConnectivityService().init());
  // Initialize Session (current logged-in owner identity) — depends on storage
  await Get.putAsync(() => SessionService().init());
  // Initialize Firebase Service (Firestore CRUD) — resolves owner via session
  await Get.putAsync(() => FirebaseService().init());
  debugPrint('All services successfully registered.');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Transport App UI Showcase',
      debugShowCheckedModeBanner: false,
      
      // Themes Setup matching guidelines
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Change to ThemeMode.system or ThemeMode.dark as required

      // Routes Setup
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}
