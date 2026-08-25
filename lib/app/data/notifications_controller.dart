import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'services/firebase_service.dart';
import 'services/session_service.dart';
import 'services/push_service.dart';
import '../core/theme/app_colors.dart';
import '../routes/app_pages.dart';
import '../../widgets/floating_notification.dart';
import '../../widgets/dialogs/app_popup.dart';
import '../../widgets/dialogs/app_snackbar.dart';

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

  final Set<String> _floatedIds = {};
  bool _primed = false; // skip floating popups for the initial snapshot
  String? _lastBoundPhone;

  int get unreadCount => items.where((n) => n['read'] == false).length;

  @override
  void onInit() {
    super.onInit();
    _bind();
    // Re-subscribe when the user logs in / out (phone or role changes).
    ever(_session.phone, (_) => _bind());
    ever(_session.role, (_) => _bind());
  }

  void _bind() {
    final phone = _session.isAdmin ? 'admin' : _session.ownerKey;
    if (phone.isEmpty) {
      _sub?.cancel();
      _sub = null;
      _lastBoundPhone = null;
      _floatedIds.clear();
      _primed = false;
      items.clear();
      return;
    }

    // Do not re-subscribe or wipe _floatedIds if already listening for this phone
    if (phone == _lastBoundPhone && _sub != null) {
      return;
    }

    _sub?.cancel();
    _floatedIds.clear();
    _primed = false;
    _lastBoundPhone = phone;

    _sub = _fb.watchNotifications(phone).listen((list) {
      // After the first snapshot, surface any brand-new notification as a
      // floating in-app notification.
      if (_primed) {
        final Set<String> surfacedThisBatchKeys = {};
        for (final n in list) {
          final id = n['id']?.toString() ?? '';
          final title = n['title']?.toString() ?? '';
          final body = n['body']?.toString() ?? '';
          final key = '$title|$body';

          final isUnread = n['read'] != true;
          if (id.isNotEmpty && !_floatedIds.contains(id) && isUnread) {
            if (!surfacedThisBatchKeys.contains(key)) {
              surfacedThisBatchKeys.add(key);
              _floatedIds.add(id);
              _floatLocal(n);
            }
          }
        }
      } else {
        // Initial snapshot: mark all current notification IDs as already floated
        _floatedIds.addAll(list.map((n) => n['id'].toString()));
        _primed = true;
      }
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

    // On Web: native browser notification when tab isn't focused
    if (GetPlatform.isWeb && Get.isRegistered<PushService>()) {
      Get.find<PushService>().showWebBrowserNotification(title, body);
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
      case 'load_rejected':
      case 'delivery_rejected':
      case 'expense_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      case 'truck_inspection_submitted':
        return (Icons.fact_check_rounded, AppColors.info);
      case 'vendor_way':
        return (Icons.directions_bus_rounded, AppColors.info);
      case 'loading_started':
        return (Icons.inventory_2_rounded, AppColors.warning);
      case 'expense_submitted':
        return (Icons.receipt_long_rounded, AppColors.warning);
      case 'load_request':
      case 'delivery_request':
      case 'parking_confirmation_request':
        return (Icons.local_parking_rounded, AppColors.tertiaryDark);
      case 'return_journey_started':
        return (Icons.directions_bus_rounded, AppColors.info);
      case 'parking_approved':
        return (Icons.verified_rounded, AppColors.success);
      case 'parking_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      case 'trip_activated':
      case 'delivery_approved':
      case 'expense_approved':
      case 'truck_ready':
      case 'inspection_approved':
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

  Future<void> deleteSingle(String id) async {
    try {
      await _fb.deleteSingleNotification(id);
      items.removeWhere((n) => (n['id'] ?? '').toString() == id);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    if (items.isEmpty) return;
    AppPopup.showConfirmation(
      title: 'Delete All Notifications?',
      description: 'Are you sure you want to permanently delete all notifications?',
      confirmText: 'Delete All',
      onConfirm: () async {
        AppPopup.showLoading(message: 'Deleting notifications...');
        try {
          await _fb.deleteAllNotifications(_session.ownerKey);
          items.clear();
          AppPopup.hideLoading();
          AppSnackBar.showSuccess(
            title: 'Cleared',
            message: 'All notifications permanently deleted.',
          );
        } catch (e) {
          AppPopup.hideLoading();
          AppSnackBar.showError(title: 'Error', message: e.toString());
        }
      },
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
