import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/data/notifications_controller.dart';
import '../app/data/services/firebase_service.dart';
import '../app/data/services/push_service.dart';
import '../app/data/services/session_service.dart';
import '../app/core/theme/app_colors.dart';
import '../app/routes/app_pages.dart';
import 'app_text.dart';
import 'dialogs/app_snackbar.dart';

/// Bell icon with an unread badge that opens the notifications sheet.
/// Works for both driver and admin (uses the shared [NotificationsController]).
class NotificationBell extends StatelessWidget {
  final Color color;

  const NotificationBell({super.key, this.color = Colors.white});

  /// Opens the notifications bottom sheet from anywhere (dashboard tiles etc.).
  void open(BuildContext context) {
    if (!Get.isRegistered<NotificationsController>()) return;
    _openSheet(context, Get.find<NotificationsController>());
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NotificationsController>()) {
      return const SizedBox.shrink();
    }
    final c = Get.find<NotificationsController>();
    return Obx(() {
      final unread = c.unreadCount;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_rounded, color: color),
            tooltip: 'Notifications',
            onPressed: () => _openSheet(context, c),
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: AppText(unread > 9 ? '9+' : '$unread',
                    style: AppTextStyle.labelMedium,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center),
              ),
            ),
        ],
      );
    });
  }

  void _openSheet(BuildContext context, NotificationsController c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1F1B18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: AppText('Notifications',
                                style: AppTextStyle.headlineSmall,
                                fontWeight: FontWeight.w700),
                          ),
                          Obx(() {
                            if (c.items.isEmpty) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.unreadCount > 0)
                                  TextButton(
                                    onPressed: c.markAllRead,
                                    child: const AppText('Mark read',
                                        style: AppTextStyle.labelMedium,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                TextButton.icon(
                                  onPressed: c.deleteAll,
                                  icon: const Icon(Icons.delete_sweep_rounded,
                                      color: Colors.red, size: 18),
                                  label: const AppText('Delete All',
                                      style: AppTextStyle.labelMedium,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    if (kIsWeb && Get.isRegistered<PushService>())
                      _enableNotificationsBanner(setSheetState),
                    const Divider(height: 1),
                    Expanded(
                      child: Obx(() {
                        if (c.items.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_rounded,
                                    size: 48, color: AppColors.textHint),
                                SizedBox(height: 10),
                                AppText('No notifications yet',
                                    style: AppTextStyle.bodyMedium),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: c.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _tile(c, c.items[i], isDark),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Web-only banner shown while the browser hasn't granted notification
  /// permission yet — tapping "Enable" makes the request from this real user
  /// gesture (far more reliable than the silent automatic request at boot).
  Widget _enableNotificationsBanner(StateSetter setSheetState) {
    final push = Get.find<PushService>();
    final permission = push.webNotificationPermission;
    if (permission == 'granted') return const SizedBox.shrink();

    final denied = permission == 'denied';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tertiary),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: AppColors.tertiaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              denied
                  ? 'Notifications blocked hain. Browser site settings se allow karein.'
                  : 'Floating notifications abhi off hain.',
              style: AppTextStyle.labelMedium,
              color: AppColors.tertiaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!denied)
            TextButton(
              onPressed: () async {
                final granted = await push.requestNotificationPermission();
                setSheetState(() {});
                if (granted) {
                  AppSnackBar.showSuccess(
                    title: 'Notifications On ✅',
                    message: 'Ab floating notifications aayengi.',
                  );
                } else {
                  AppSnackBar.showWarning(
                    title: 'Not Enabled',
                    message: 'Permission allow nahi hui.',
                  );
                }
              },
              child: const AppText('Enable',
                  style: AppTextStyle.labelLarge,
                  color: AppColors.tertiaryDark,
                  fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _tile(
      NotificationsController c, Map<String, dynamic> n, bool isDark) {
    final type = n['type']?.toString() ?? 'info';
    final read = n['read'] == true;
    final tripId = n['tripId']?.toString() ?? '';
    final (icon, tint) = _style(type);

    return InkWell(
      onTap: () {
        if (!read && n['id'] != null) c.markRead(n['id'].toString());
        Get.back(); // close the sheet
        // Open the detail page where the same Accept/Reject action is available.
        Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: n);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: read ? Colors.transparent : tint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(n['title']?.toString() ?? '',
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.w700),
                      const SizedBox(height: 2),
                      AppText(n['body']?.toString() ?? '',
                          style: AppTextStyle.bodyMedium),
                    ],
                  ),
                ),
                if (!read)
                  Container(
                    margin: const EdgeInsets.only(left: 6, top: 4),
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
            // Trip approval requests (load / delivery) → Approve/Reject here.
            // Hidden once the action has been taken (one-time per notification).
            if (_isTripApproval(type) &&
                tripId.isNotEmpty &&
                n['actioned'] != true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(c, n, type, tripId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(c, n, type, tripId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isTripApproval(String type) =>
      type == 'load_request' || type == 'delivery_request';

  Future<void> _approve(NotificationsController c, Map<String, dynamic> n,
      String type, String tripId) async {
    final fb = Get.find<FirebaseService>();
    final adminName = _sessionName();
    if (type == 'delivery_request') {
      await fb.approveDelivery(tripId, adminName: adminName);
      AppSnackBar.showSuccess(
          title: 'Delivery Approved ✅', message: 'Trip $tripId is complete.');
    } else {
      final err = await fb.approveLoad(tripId, adminName: adminName);
      if (err != null) {
        AppSnackBar.showWarning(title: 'Approve Nahi Hua', message: err);
        return; // keep the notification actionable
      }
      AppSnackBar.showSuccess(
          title: 'Load Approved ✅', message: 'Trip $tripId is now ACTIVE.');
    }
    if (n['id'] != null) c.markActioned(n['id'].toString());
  }

  Future<void> _reject(NotificationsController c, Map<String, dynamic> n,
      String type, String tripId) async {
    final fb = Get.find<FirebaseService>();
    final adminName = _sessionName();
    if (type == 'delivery_request') {
      await fb.rejectDelivery(tripId, adminName: adminName);
      AppSnackBar.showInfo(
          title: 'Delivery Rejected', message: 'Trip $tripId kept active.');
    } else {
      await fb.rejectLoad(tripId, adminName: adminName);
      AppSnackBar.showInfo(
          title: 'Load Rejected', message: 'Trip $tripId sent back.');
    }
    if (n['id'] != null) c.markActioned(n['id'].toString());
  }

  String _sessionName() {
    try {
      return Get.find<SessionService>().name.value;
    } catch (_) {
      return 'Admin';
    }
  }

  (IconData, Color) _style(String type) {
    switch (type) {
      case 'trip_assigned':
        return (Icons.local_shipping_rounded, AppColors.primary);
      case 'trip_accepted':
        return (Icons.check_circle_rounded, AppColors.success);
      case 'trip_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      case 'trip_delivered':
      case 'delivery_approved':
        return (Icons.flag_rounded, AppColors.success);
      case 'trip_activated':
        return (Icons.play_circle_fill_rounded, AppColors.success);
      case 'load_request':
        return (Icons.inventory_2_rounded, AppColors.tertiaryDark);
      case 'delivery_request':
        return (Icons.where_to_vote_rounded, AppColors.primary);
      case 'load_rejected':
      case 'delivery_rejected':
        return (Icons.error_rounded, AppColors.error);
      case 'expense_submitted':
        return (Icons.receipt_long_rounded, AppColors.tertiaryDark);
      case 'expense_approved':
        return (Icons.check_circle_rounded, AppColors.success);
      case 'expense_rejected':
        return (Icons.cancel_rounded, AppColors.error);
      case 'check_in':
        return (Icons.login_rounded, AppColors.success);
      case 'check_out':
        return (Icons.logout_rounded, AppColors.textSecondary);
      case 'truck_assigned':
        return (Icons.local_shipping_rounded, AppColors.primary);
      case 'truck_issue':
        return (Icons.report_problem_rounded, AppColors.error);
      case 'truck_ready':
        return (Icons.verified_rounded, AppColors.success);
      case 'vendor_way':
        return (Icons.directions_rounded, AppColors.info);
      case 'loading_started':
        return (Icons.inventory_2_rounded, AppColors.tertiaryDark);
      case 'set_destination_reminder':
        return (Icons.add_location_alt_rounded, AppColors.error);
      default:
        return (Icons.notifications_rounded, AppColors.tertiaryDark);
    }
  }
}
