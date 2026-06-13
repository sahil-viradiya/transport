import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService extends GetxService {
  late final SharedPreferences _prefs;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // Generic write
  Future<bool> write(String key, dynamic value) async {
    if (value is String) {
      return await _prefs.setString(key, value);
    } else if (value is int) {
      return await _prefs.setInt(key, value);
    } else if (value is double) {
      return await _prefs.setDouble(key, value);
    } else if (value is bool) {
      return await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      return await _prefs.setStringList(key, value);
    }
    return false;
  }

  // Generic read
  T? read<T>(String key) {
    if (T == String) {
      return _prefs.getString(key) as T?;
    } else if (T == int) {
      return _prefs.getInt(key) as T?;
    } else if (T == double) {
      return _prefs.getDouble(key) as T?;
    } else if (T == bool) {
      return _prefs.getBool(key) as T?;
    } else if (T == List<String>) {
      return _prefs.getStringList(key) as T?;
    }
    return _prefs.get(key) as T?;
  }

  // Remove key
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  // Clear all
  Future<bool> clear() async {
    return await _prefs.clear();
  }
}
