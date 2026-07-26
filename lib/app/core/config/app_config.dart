import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/storage_service.dart';

/// Global Application Configuration Manager
/// 
/// Controls application-wide execution mode and global localization:
/// - **LIVE MODE** (`isMockMode = false`): Uses real Firebase Phone Auth (SMS), real Firestore & Storage.
/// - **MOCK MODE** (`isMockMode = true`): Uses mock OTP (`123456`) and local/mock test fallbacks.
/// - **LOCALIZATION**: English (`en_US`), Hindi (`hi_IN`), Spanish (`es_ES`).
class AppConfig {
  static const String _mockModeKey = 'app_config_is_mock_mode';
  static const String _languageKey = 'app_config_language_code';

  /// Default mode setting when app starts for the first time.
  static const bool defaultIsMockMode = false;

  /// Reactive mode state accessible across all screens and controllers.
  static final RxBool isMockMode = defaultIsMockMode.obs;

  /// Reactive active locale state
  static final Rx<Locale> currentLocale = const Locale('en', 'US').obs;

  /// Initialize global config from local storage (if user changed it previously).
  static void init() {
    try {
      if (Get.isRegistered<StorageService>()) {
        final storage = Get.find<StorageService>();
        
        // Mode
        final savedMode = storage.read<bool>(_mockModeKey);
        if (savedMode != null) {
          isMockMode.value = savedMode;
        }

        // Locale
        final savedLang = storage.read<String>(_languageKey);
        if (savedLang != null) {
          currentLocale.value = _parseLocale(savedLang);
          Get.updateLocale(currentLocale.value);
        }
      }
    } catch (e) {
      debugPrint('[AppConfig] Init config error: $e');
    }
    _logCurrentMode();
  }

  /// Change application language dynamically
  static Future<void> changeLanguage(String langCode) async {
    final newLocale = _parseLocale(langCode);
    currentLocale.value = newLocale;
    Get.updateLocale(newLocale);
    try {
      if (Get.isRegistered<StorageService>()) {
        final storage = Get.find<StorageService>();
        await storage.write(_languageKey, langCode);
      }
    } catch (e) {
      debugPrint('[AppConfig] Storage write language error: $e');
    }
  }

  static Locale _parseLocale(String langCode) {
    switch (langCode) {
      case 'hi':
      case 'hi_IN':
        return const Locale('hi', 'IN');
      case 'es':
      case 'es_ES':
        return const Locale('es', 'ES');
      default:
        return const Locale('en', 'US');
    }
  }

  /// Toggle or set application mode globally at runtime and persist choice.
  static Future<void> setMockMode(bool value) async {
    isMockMode.value = value;
    try {
      if (Get.isRegistered<StorageService>()) {
        final storage = Get.find<StorageService>();
        await storage.write(_mockModeKey, value);
      }
    } catch (e) {
      debugPrint('[AppConfig] Storage write failed: $e');
    }
    _logCurrentMode();
  }

  /// Toggle between Live and Mock mode.
  static Future<void> toggleMode() async {
    await setMockMode(!isMockMode.value);
  }

  /// Convenience getters
  static bool get isMock => isMockMode.value;
  static bool get isLive => !isMockMode.value;

  static void _logCurrentMode() {
    debugPrint('================================================================');
    debugPrint('   [APP CONFIG] CURRENT MODE: ${isMockMode.value ? "MOCK / DEBUG MODE (OTP: 123456)" : "LIVE MODE (Real Firebase SMS & Data)"}');
    debugPrint('   [APP CONFIG] LOCALE: ${currentLocale.value.languageCode}_${currentLocale.value.countryCode}');
    debugPrint('================================================================');
  }
}
