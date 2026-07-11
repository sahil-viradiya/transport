import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'services/firebase_service.dart';
import 'services/session_service.dart';
import 'services/push_service.dart';
import '../core/theme/app_colors.dart';
import '../routes/app_pages.dart';
import '../../widgets/floating_notification.dart';

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
    final title = n['title']?.toString() ?? 'Notification';
    final body = n['body']?.toString() ?? '';
    final type = n['type']?.toString() ?? 'info';

    // In-app floating card (top-right) — always visible while the app is open,
    // no browser/OS permission needed. This is the primary visual cue for a new
    // trip, accepted trip, inspection, approval request, completion, etc.
    final (icon, color) = _floatStyle(type);
    FloatingNotify.show(
      title: title,
      body: body,
      icon: icon,
      color: color,
      onTap: () {
        try {
          Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: n);
        } catch (_) {}
      },
    );

    // Also route to the OS/browser layer: a real heads-up on mobile, or a
    // native browser notification on web (useful when the tab isn't focused).
    if (!Get.isRegistered<PushService>()) return;
    final push = Get.find<PushService>();
    if (GetPlatform.isWeb) {
      push.showWebBrowserNotification(title, body);
    } else {
      final payload = jsonEncode({
        'type': type,
        'tripId': n['tripId']?.toString() ?? '',
        'refId': n['refId']?.toString() ?? '',
        'id': n['id']?.toString() ?? '',
      });
      push.showLocal(title, body, payload: payload);
    }
  }

  /// Icon + accent colour for a floating notification, keyed by its type — so
  /// key events (new trip, accepted, inspection, approval, completed) read at a
  /// glance.
  (IconData, Color) _floatStyle(String type) {
    switch (type) {
      case 'trip_assigned':
        return (Icons.local_shipping_rounded, AppColors.primary);
      case 'trip_accepted':
        return (Icons.check_circle_rounded, AppColors.success);
      case 'trip_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      case 'truck_inspection_submitted':
        return (Icons.fact_check_rounded, AppColors.info);
      case 'load_request':
      case 'delivery_request':
        return (Icons.pending_actions_rounded, AppColors.tertiaryDark);
      case 'trip_activated':
      case 'delivery_approved':
        return (Icons.task_alt_rounded, AppColors.success);
      case 'check_in':
        return (Icons.login_rounded, AppColors.success);
      case 'check_out':
        return (Icons.logout_rounded, AppColors.textSecondary);
      default:
        return (Icons.notifications_active_rounded, AppColors.primary);
    }
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
