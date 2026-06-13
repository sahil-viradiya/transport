import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/services/storage_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServices();
  runApp(const MyApp());
}

Future<void> initServices() async {
  print('Initializing critical GetX services...');
  // Initialize Firebase Core
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully.');
  } catch (e) {
    print('Firebase initialization failed: $e');
    print('App running in Mock Mode.');
  }

  // Initialize Shared Preferences Storage
  await Get.putAsync(() => StorageService().init());
  // Initialize Live Connectivity Checker
  await Get.putAsync(() => ConnectivityService().init());
  print('All services successfully registered.');
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
