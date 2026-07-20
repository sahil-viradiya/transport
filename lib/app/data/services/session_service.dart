import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';

/// Single source of truth for the currently logged-in user (the truck owner).
///
/// Previously the app read the identity from scattered SharedPreferences keys
/// and, worse, all rich profile/location data was hardcoded to a single
/// `drivers/rajesh_kumar` document. This service centralises identity so every
/// controller and the [FirebaseService] can scope reads/writes to the real
/// signed-in owner.
class SessionService extends GetxService {
  final StorageService _storage;

  SessionService({StorageService? storage})
      : _storage = storage ?? Get.find<StorageService>();

  // Persisted identity, also exposed reactively for the UI.
  final RxString uid = ''.obs;
  final RxString phone = ''.obs; // normalised, e.g. +919876543210
  final RxString name = ''.obs;
  final RxString role = 'owner'.obs;
  final RxString avatarUrl = ''.obs;

  static const _kLoggedIn = 'isLoggedIn';
  static const _kPhone = 'userPhone';
  static const _kRole = 'userRole';
  static const _kName = 'userName';
  static const _kUid = 'userUid';
  static const _kAvatar = 'userAvatar';

  Future<SessionService> init() async {
    // Restore from local storage first (works offline / before Firebase ready).
    phone.value = _storage.read<String>(_kPhone) ?? '';
    role.value = _storage.read<String>(_kRole) ?? 'owner';
    name.value = _storage.read<String>(_kName) ?? '';
    uid.value = _storage.read<String>(_kUid) ?? '';
    avatarUrl.value = _storage.read<String>(_kAvatar) ?? '';

    // Reconcile with the live Firebase Auth user when available.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        uid.value = user.uid;
        if ((user.phoneNumber ?? '').isNotEmpty) {
          phone.value = normalizePhone(user.phoneNumber!);
        }
      }
    } catch (_) {
      // Firebase not initialised (mock mode) — keep stored values.
    }
    return this;
  }

  bool get isLoggedIn =>
      (_storage.read<bool>(_kLoggedIn) ?? false) && ownerKey.isNotEmpty;

  bool get isAdmin => role.value == 'admin';

  /// The Firestore document id used to scope a user's private data
  /// (profile, trips, expenses, trucks). Phone is stable across devices and is
  /// what Firebase phone-auth issues, so we key everything off it.
  String get ownerKey => phone.value;

  /// Persist a freshly authenticated session.
  Future<void> setSession({
    required String phone,
    String? uid,
    String? name,
    String? role,
    String? avatarUrl,
  }) async {
    this.phone.value = normalizePhone(phone);
    if (uid != null) this.uid.value = uid;
    if (name != null) this.name.value = name;
    if (role != null) this.role.value = role;
    if (avatarUrl != null) this.avatarUrl.value = avatarUrl;

    await _storage.write(_kLoggedIn, true);
    await _storage.write(_kPhone, this.phone.value);
    await _storage.write(_kRole, this.role.value);
    await _storage.write(_kName, this.name.value);
    await _storage.write(_kUid, this.uid.value);
    await _storage.write(_kAvatar, this.avatarUrl.value);
  }

  /// Update individual cached fields after the user edits their profile.
  Future<void> updateCachedProfile({String? name, String? avatarUrl}) async {
    if (name != null) {
      this.name.value = name;
      await _storage.write(_kName, name);
    }
    if (avatarUrl != null) {
      this.avatarUrl.value = avatarUrl;
      await _storage.write(_kAvatar, avatarUrl);
    }
  }

  Future<void> clear() async {
    uid.value = '';
    phone.value = '';
    name.value = '';
    role.value = 'owner';
    avatarUrl.value = '';
    await _storage.remove(_kLoggedIn);
    await _storage.remove(_kPhone);
    await _storage.remove(_kRole);
    await _storage.remove(_kName);
    await _storage.remove(_kUid);
    await _storage.remove(_kAvatar);
  }

  /// Normalise a phone string to the `+<countrycode><number>` form used as the
  /// canonical key. Strips spaces, dashes and parentheses.
  static String normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-()+]'), '').trim();
  }
}
