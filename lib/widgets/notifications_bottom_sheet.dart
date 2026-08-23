import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/app/core/utils/time_utils.dart';
import 'package:transport/app/data/notifications_controller.dart';
import 'package:transport/app/routes/app_pages.dart';

class NotificationsBottomSheetContent extends GetView<NotificationsController> {
  const NotificationsBottomSheetContent({super.key});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Header: Back + Title + Mark all read
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
                    onPressed: () => Navigator.of(context).pop(),
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
                    if (controller.items.isEmpty) {
                      return const SizedBox(width: 48);
                    }
                    return TextButton(
                      onPressed: controller.markAllRead,
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
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Notifications List
            Expanded(
              child: Obx(() {
                final list = controller.items;
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.03),
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
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (ctx, i) {
                          final item = list[i];
                          final isUnread = !(item['read'] as bool? ?? false);
                          final title =
                              item['title']?.toString() ?? 'Notification';
                          final body = item['body']?.toString() ?? '';
                          final createdAt = item['createdAt'];
                          final timeStr = _formatTimestamp(createdAt);
                          final (icon, iconColor, bgColor) =
                              _style(item['type']?.toString());

                          return InkWell(
                            onTap: () {
                              controller
                                  .markRead(item['id']?.toString() ?? '');
                              Get.back();
                              Get.toNamed(Routes.NOTIFICATION_DETAIL,
                                  arguments: item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              color: isUnread
                                  ? (isDark
                                      ? const Color(0xFF2563EB)
                                          .withValues(alpha: 0.05)
                                      : const Color(0xFFF0FDF4)
                                          .withValues(alpha: 0.5))
                                  : Colors.transparent,
                              child: Row(
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
                                    child:
                                        Icon(icon, color: iconColor, size: 19),
                                  ),
                                  const SizedBox(width: 14),

                                  // Text info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
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
                                            if (isUnread) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 7,
                                                height: 7,
                                                margin:
                                                    const EdgeInsets.only(top: 4),
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
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            body,
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(String? type) {
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
