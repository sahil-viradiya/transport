import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/widgets/app_text.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/app/core/utils/time_utils.dart';
import 'package:transport/app/data/notifications_controller.dart';
import 'package:transport/app/routes/app_pages.dart';

class NotificationsBottomSheetContent extends GetView<NotificationsController> {
  const NotificationsBottomSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.notifications_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                const AppText('Notifications',
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold),
                const Spacer(),
                Obx(() {
                  if (controller.items.isEmpty) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.unreadCount > 0)
                        TextButton(
                          onPressed: controller.markAllRead,
                          child: const AppText('Mark read',
                              style: AppTextStyle.labelMedium,
                              color: AppColors.primary),
                        ),
                      TextButton.icon(
                        onPressed: controller.deleteAll,
                        icon: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.red, size: 18),
                        label: const AppText('Delete All',
                            style: AppTextStyle.labelMedium,
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final list = controller.items;
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const AppText('No notifications yet',
                          style: AppTextStyle.bodyLarge,
                          color: AppColors.textSecondary),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                itemBuilder: (ctx, i) {
                  final item = list[i];
                  final isUnread = !(item['read'] as bool? ?? false);
                  final title = item['title']?.toString() ?? 'Notification';
                  final body = item['body']?.toString() ?? '';
                  final createdAt = item['createdAt'];
                  final timeStr = timeAgo(createdAt);

                  return Material(
                    color: isUnread
                        ? (isDark
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.05))
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        controller.markRead(item['id']?.toString() ?? '');
                        Get.back();
                        Get.toNamed(Routes.NOTIFICATION_DETAIL, arguments: item);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _iconBgForType(item['type']?.toString()),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconForType(item['type']?.toString()),
                                color: _iconColorForType(item['type']?.toString()),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppText(
                                          title,
                                          style: AppTextStyle.bodyMedium,
                                          fontWeight: isUnread
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty)
                                        AppText(timeStr,
                                            style: AppTextStyle.labelMedium,
                                            color: AppColors.textSecondary),
                                    ],
                                  ),
                                  if (body.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    AppText(
                                      body,
                                      style: AppTextStyle.bodyMedium,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'trip_assigned':
      case 'trip_accepted':
        return Icons.local_shipping_rounded;
      case 'expense_submitted':
      case 'expense_approved':
        return Icons.receipt_long_rounded;
      case 'trip_rejected':
      case 'expense_rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconBgForType(String? type) {
    switch (type) {
      case 'trip_assigned':
      case 'trip_accepted':
      case 'expense_approved':
        return const Color(0xFFD1FAE5);
      case 'trip_rejected':
      case 'expense_rejected':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  Color _iconColorForType(String? type) {
    switch (type) {
      case 'trip_assigned':
      case 'trip_accepted':
      case 'expense_approved':
        return const Color(0xFF047857);
      case 'trip_rejected':
      case 'expense_rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF1E40AF);
    }
  }
}
