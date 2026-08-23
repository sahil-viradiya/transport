import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/data/notifications_controller.dart';
import '../app/data/services/firebase_service.dart';
import '../app/data/services/push_service.dart';
import '../app/data/services/session_service.dart';
import '../app/core/theme/app_colors.dart';
import '../app/core/utils/time_utils.dart';
import '../app/routes/app_pages.dart';
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
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    });
  }

  static String _formatTimestamp(dynamic time) {
    final dt = parseDateTime(time);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hourStr = hour.toString().padLeft(2, '0');
    return '$day $month $year, $hourStr:$minute $period';
  }

  void _openSheet(BuildContext context, NotificationsController c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return SafeArea(
                  child: Column(
                    children: [
                      // Top App Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                size: 22,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                            Expanded(
                              child: Text(
                                'Notifications',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Obx(() {
                              if (c.items.isEmpty) {
                                return const SizedBox(width: 48);
                              }
                              return TextButton(
                                onPressed: c.markAllRead,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      if (kIsWeb && Get.isRegistered<PushService>())
                        _enableNotificationsBanner(setSheetState),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Notifications List
                      Expanded(
                        child: Obx(() {
                          if (c.items.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_off_rounded,
                                      size: 32,
                                      color: isDark ? Colors.white38 : AppColors.textHint,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: c.items.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark
                                        ? Colors.white10
                                        : const Color(0xFFF1F5F9),
                                  ),
                                  itemBuilder: (_, i) =>
                                      _tile(c, c.items[i], isDark),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _enableNotificationsBanner(StateSetter setSheetState) {
    final push = Get.find<PushService>();
    final permission = push.webNotificationPermission;
    if (permission == 'granted') return const SizedBox.shrink();

    final denied = permission == 'denied';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
            child: Text(
              denied
                  ? 'Notifications blocked hain. Browser site settings se allow karein.'
                  : 'Floating notifications abhi off hain.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.tertiaryDark,
                fontWeight: FontWeight.w600,
              ),
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
              child: const Text(
                'Enable',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.tertiaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    final (icon, iconColor, bgColor) = _style(type);
    final timeStr = _formatTimestamp(n['createdAt'] ?? n['timestamp']);

    return InkWell(
      onTap: () {
        if (!read && n['id'] != null) c.markRead(n['id'].toString());
        Get.back(); // close the sheet
        Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: n);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: read
            ? Colors.transparent
            : (isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                : const Color(0xFFF0FDF4).withValues(alpha: 0.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Icon Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 14),

                // Content: Title + Timestamp + Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n['title']?.toString() ?? 'Notification',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                height: 1.25,
                              ),
                              softWrap: true,
                            ),
                          ),
                          if (!read) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if ((n['body']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          n['body']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Inline Trip Approval actions (Approve / Reject)
            if (_isTripApproval(type) &&
                tripId.isNotEmpty &&
                n['actioned'] != true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 52), // indent aligned with text
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(c, n, type, tripId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(c, n, type, tripId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Approve',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
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
        return;
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

  (IconData, Color, Color) _style(String type) {
    switch (type) {
      // Green style (Inspection Approved, Trip Accepted, Ready, Delivered)
      case 'inspection_approved':
      case 'truck_ready':
      case 'trip_accepted':
      case 'trip_delivered':
      case 'delivery_approved':
      case 'expense_approved':
        return (
          Icons.check_circle_outline_rounded,
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
        );

      // Blue style (Trip Assigned, Truck Assigned, Active)
      case 'trip_assigned':
      case 'truck_assigned':
      case 'trip_activated':
        return (
          Icons.radio_button_checked_rounded,
          const Color(0xFF2563EB),
          const Color(0xFFDBEAFE),
        );

      // Cyan / Teal style (Destination Set, Route, Way)
      case 'set_destination_reminder':
      case 'vendor_way':
      case 'destination_set':
        return (
          Icons.location_on_outlined,
          const Color(0xFF0891B2),
          const Color(0xFFCFFAFE),
        );

      // Purple style (Checked In, General confirmations)
      case 'check_in':
      case 'check_out':
        return (
          Icons.check_rounded,
          const Color(0xFF6366F1),
          const Color(0xFFEDE9FE),
        );

      // Red style (Issues, Rejections)
      case 'truck_issue':
      case 'trip_rejected':
      case 'load_rejected':
      case 'delivery_rejected':
      case 'expense_rejected':
        return (
          Icons.cancel_outlined,
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
        );

      // Amber style (Pending Inspection, Load requests, Reminders)
      case 'load_request':
      case 'delivery_request':
      case 'loading_started':
      case 'expense_submitted':
      default:
        return (
          Icons.fact_check_outlined,
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
        );
    }
  }
}
