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

  /// Normalise a phone string to the canonical E.164 (`+91XXXXXXXXXX`) format
  /// used everywhere in the project. Strips spaces, dashes and formatting.
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    if (digits.length == 10) {
      return '+91$digits';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    } else if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    } else if (trimmed.startsWith('+')) {
      return '+$digits';
    }
    return '+91$digits';
  }

  /// Returns all plausible search variants for a given phone number string
  /// (canonical +91, without +, 10-digit base, 12-digit, spaces, etc.)
  /// used to query legacy documents in Firestore.
  static List<String> getPhoneVariants(String raw) {
    final Set<String> variants = {};
    final canonical = normalizePhone(raw);
    if (canonical.isNotEmpty) {
      variants.add(canonical); // +91XXXXXXXXXX
      variants.add(canonical.replaceFirst('+', '')); // 91XXXXXXXXXX
    }

    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      variants.add(trimmed);
      variants.add(trimmed.replaceAll(' ', ''));
    }

    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isNotEmpty) {
      variants.add(digitsOnly);
    }

    if (digitsOnly.length >= 10) {
      final base10 = digitsOnly.substring(digitsOnly.length - 10);
      final part1 = base10.substring(0, 5);
      final part2 = base10.substring(5);

      variants.add(base10);
      variants.add('$part1 $part2');
      variants.add('+91$base10');
      variants.add('+91 $base10');
      variants.add('+91 $part1 $part2');
      variants.add('+91-$base10');
      variants.add('91$base10');
      variants.add('91 $base10');
      variants.add('91 $part1 $part2');
      variants.add('0$base10');
      variants.add('0 $part1 $part2');
    }

    return variants.toList();
  }
}
