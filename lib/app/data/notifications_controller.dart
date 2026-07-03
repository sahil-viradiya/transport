import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'services/firebase_service.dart';
import 'services/session_service.dart';
import 'services/push_service.dart';

/// App-wide live feed of the signed-in user's notifications (driver or admin).
/// Registered permanently in main() and rebinds whenever the session changes.
///
/// As new notifications arrive on the live Firestore stream, it also fires an OS
/// heads-up (floating) notification via [PushService.showLocal] — so floating
/// notifications work in the foreground without deploying the Cloud Function.
class NotificationsController extends GetxController {
  final _fb = Get.find<FirebaseService>();
  final _session = Get.find<SessionService>();

  final RxList<Map<String, dynamic>> items = <Map<String, dynamic>>[].obs;
  StreamSubscription? _sub;

  final Set<String> _seenIds = {};
  bool _primed = false; // skip floating popups for the initial snapshot

  int get unreadCount => items.where((n) => n['read'] == false).length;

  @override
  void onInit() {
    super.onInit();
    _bind();
    // Re-subscribe when the user logs in / out (phone changes).
    ever(_session.phone, (_) => _bind());
  }

  void _bind() {
    _sub?.cancel();
    _seenIds.clear();
    _primed = false;
    final phone = _session.ownerKey;
    if (phone.isEmpty) {
      items.clear();
      return;
    }
    _sub = _fb.watchNotifications(phone).listen((list) {
      // After the first snapshot, surface any brand-new notification as a
      // floating OS notification.
      if (_primed) {
        for (final n in list) {
          final id = n['id']?.toString() ?? '';
          if (id.isNotEmpty && !_seenIds.contains(id) && n['read'] == false) {
            _floatLocal(n);
          }
        }
      }
      _seenIds
        ..clear()
        ..addAll(list.map((n) => n['id'].toString()));
      _primed = true;
      items.assignAll(list);
    });
  }

  void _floatLocal(Map<String, dynamic> n) {
    if (!Get.isRegistered<PushService>()) return;
    final payload = jsonEncode({
      'type': n['type']?.toString() ?? 'info',
      'tripId': n['tripId']?.toString() ?? '',
      'refId': n['refId']?.toString() ?? '',
      'id': n['id']?.toString() ?? '',
    });
    Get.find<PushService>().showLocal(
      n['title']?.toString() ?? 'Notification',
      n['body']?.toString() ?? '',
      payload: payload,
    );
  }

  Future<void> markRead(String id) => _fb.markNotificationRead(id);

  Future<void> markActioned(String id) => _fb.markNotificationActioned(id);

  Future<void> markAllRead() => _fb.markAllNotificationsRead(_session.ownerKey);

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
