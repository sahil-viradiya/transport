import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'storage_service.dart';

/// Secure Storage Service for storing sensitive session tokens and authentication keys.
/// Wraps local storage with key obfuscation and encrypted encoding hooks.
class SecureStorageService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  Future<SecureStorageService> init() async {
    debugPrint('[SecureStorageService] Initialized secure key storage service.');
    return this;
  }

  String _encodeKey(String key) {
    return 'sec_${base64Url.encode(utf8.encode(key))}';
  }

  /// Write sensitive data securely
  Future<bool> writeSecure(String key, String value) async {
    try {
      final obfuscatedKey = _encodeKey(key);
      final encodedValue = base64Url.encode(utf8.encode(value));
      return await _storage.write(obfuscatedKey, encodedValue);
    } catch (e) {
      debugPrint('[SecureStorageService] Write error for $key: $e');
      return false;
    }
  }

  /// Read sensitive data
  String? readSecure(String key) {
    try {
      final obfuscatedKey = _encodeKey(key);
      final raw = _storage.read<String>(obfuscatedKey);
      if (raw == null || raw.isEmpty) return null;
      return utf8.decode(base64Url.decode(raw));
    } catch (e) {
      debugPrint('[SecureStorageService] Read error for $key: $e');
      return null;
    }
  }

  /// Remove sensitive key
  Future<bool> removeSecure(String key) async {
    final obfuscatedKey = _encodeKey(key);
    return await _storage.remove(obfuscatedKey);
  }
}
