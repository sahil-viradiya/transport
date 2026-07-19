import 'package:flutter/material.dart';
import 'app_text.dart';
import '../app/core/theme/app_colors.dart';

/// The "Current Trip Status" card — a vertical checklist of the trip's
/// vendor-journey stages (assign → accept → vendor → loading → destination →
/// delivery) with the current stage highlighted. Shared by the full-screen
/// [TripStatusView] (trip_details module) and the collapsible per-trip
/// timeline shown inside "My Trips".
class TripStatusTimeline extends StatelessWidget {
  final String tripId;
  final String status;
  final String? driverName;
  final String? truckNo;
  final String dropCity;

  /// Whether to render the "Current Trip Status - <id>" / driver+truck header.
  /// Collapsible list tiles usually supply their own compact title instead.
  final bool showHeader;

  final List<dynamic>? milestonesLog;
  final String? tripDate;

  const TripStatusTimeline({
    super.key,
    required this.tripId,
    required this.status,
    this.driverName,
    this.truckNo,
    this.dropCity = '',
    this.showHeader = true,
    this.milestonesLog,
    this.tripDate,
  });

  static const List<String> stages = [
    'Trip Assigned',
    'Trip Accepted',
    'On The Way',
    'Reached Vendor',
    'Loading Started',
    'Loading Completed',
    'Destination Set',
    'On The Way (Destination)',
    'Trip Completed',
  ];

  // Index 6 (Destination Set) is handled dynamically — see [_subtitleFor].
  static const List<String> _descriptions = [
    'Trip assigned by admin',
    'Driver accepted the trip',
    'Driver is on the way to vendor',
    'Driver reached vendor location',
    'Truck is loading at vendor',
    'Loading finished',
    '',
    'Truck traveling to destination',
    'Trip completed successfully',
  ];

  /// How many stages are completed for a given trip status.
  static int doneCount(String status) {
    switch (status) {
      case 'PENDING':
        return 1;
      case 'ASSIGNED':
        return 2;
      case 'EN_ROUTE_VENDOR':
        return 3;
      case 'LOADING':
      case 'LOAD_REJECTED':
        return 5;
      case 'LOAD_REQUESTED':
        return 6;
      case 'ACTIVE NOW':
      case 'DELIVERY_REJECTED':
        return 7;
      case 'DELIVERY_REQUESTED':
        return 8;
      case 'DELIVERED':
        return 9;
      default:
        return 1;
    }
  }

  // Destination stays hidden from the driver until the load is approved
  // (ACTIVE NOW+), matching TripDetailsController.destinationRevealed — so
  // this node only names the city once it's actually been revealed.
  String _subtitleFor(int index, bool isDone) {
    if (index != 6) return _descriptions[index];
    if (!isDone) return 'Waiting for admin to set destination';
    return dropCity.isNotEmpty
        ? 'Destination: $dropCity'
        : 'Destination set by admin';
  }

  String _formatTimeOnly(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      if (ts.contains(RegExp(r'(AM|PM)', caseSensitive: false))) {
        final match = RegExp(r'\d{1,2}:\d{2}\s*(?:AM|PM)', caseSensitive: false).firstMatch(ts);
        if (match != null) return match.group(0)!;
      }
      
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) {
        final hour = parsed.hour;
        final minute = parsed.minute;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute < 10 ? '0$minute' : '$minute';
        final hourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
        return '$hourStr:$minStr $period';
      }
      
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(ts);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute < 10 ? '0$minute' : '$minute';
        final hourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
        return '$hourStr:$minStr $period';
      }
    } catch (_) {}
    return ts;
  }

  List<String> getTimestamps() {
    final List<String> times = List.filled(9, '');
    
    String baseTimeStr = _formatTimeOnly(tripDate);
    if (baseTimeStr.isEmpty) {
      baseTimeStr = '08:00 AM';
    }
    
    DateTime baseDateTime = DateTime(2026, 10, 24, 8, 0);
    try {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(baseTimeStr);
      if (timeMatch != null) {
        var hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final isPm = timeMatch.group(3)!.toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        baseDateTime = DateTime(2026, 10, 24, hour, minute);
      }
    } catch (_) {}

    final logs = milestonesLog ?? [];
    String? ts1;

    ts1 = baseTimeStr;

    String? findLogTimestamp(List<dynamic> logs, int? milestoneNum, String labelKeyword) {
      for (final log in logs) {
        if (log is Map) {
          final m = log['milestone'] as num?;
          final label = (log['label'] ?? '').toString().toLowerCase();
          final timestamp = (log['timestamp'] ?? '').toString();
          if (timestamp.isNotEmpty) {
            if (milestoneNum != null && m?.toInt() == milestoneNum) {
              return timestamp;
            }
            if (label.contains(labelKeyword.toLowerCase())) {
              return timestamp;
            }
          }
        }
      }
      return null;
    }

    final acceptTs = findLogTimestamp(logs, null, 'Accepted') ?? findLogTimestamp(logs, null, 'Confirm');
    final onWayTs = findLogTimestamp(logs, 1, 'Way') ?? findLogTimestamp(logs, 1, 'nikla');
    final reachedVendorTs = findLogTimestamp(logs, null, 'Reached Vendor') ?? findLogTimestamp(logs, null, 'pahuncha');
    final loadingStartedTs = findLogTimestamp(logs, 2, 'Loading Started') ?? findLogTimestamp(logs, 2, 'shuru');
    final loadingCompletedTs = findLogTimestamp(logs, 3, 'Loaded') ?? findLogTimestamp(logs, 3, 'finished') ?? findLogTimestamp(logs, 3, 'Completed');
    final destinationSetTs = findLogTimestamp(logs, null, 'Destination Set');
    final onWayDestTs = findLogTimestamp(logs, null, 'Way (Destination)');
    final completedTs = findLogTimestamp(logs, 4, 'Delivered') ?? findLogTimestamp(logs, 4, 'Completed');

    final done = doneCount(status);

    String formatDateTime(DateTime dt) {
      final hour = dt.hour;
      final minute = dt.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final minStr = minute < 10 ? '0$minute' : '$minute';
      final hourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
      return '$hourStr:$minStr $period';
    }

    final increments = [0, 30, 45, 30, 15, 30, 15, 15, 30];

    DateTime currentSim = baseDateTime;
    for (var i = 0; i < 9; i++) {
      if (i > 0) {
        currentSim = currentSim.add(Duration(minutes: increments[i]));
      }

      String? actual;
      if (i == 0) actual = ts1;
      else if (i == 1) actual = acceptTs;
      else if (i == 2) actual = onWayTs;
      else if (i == 3) actual = reachedVendorTs;
      else if (i == 4) actual = loadingStartedTs;
      else if (i == 5) actual = loadingCompletedTs;
      else if (i == 6) actual = destinationSetTs;
      else if (i == 7) actual = onWayDestTs;
      else if (i == 8) actual = completedTs;

      if (actual != null) {
        times[i] = _formatTimeOnly(actual);
        try {
          final tOnly = _formatTimeOnly(actual);
          final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(tOnly);
          if (match != null) {
            var hour = int.parse(match.group(1)!);
            final minute = int.parse(match.group(2)!);
            final isPm = match.group(3)!.toUpperCase() == 'PM';
            if (isPm && hour < 12) hour += 12;
            if (!isPm && hour == 12) hour = 0;
            currentSim = DateTime(2026, 10, 24, hour, minute);
          }
        } catch (_) {}
      } else {
        if (i < done || (i == done && status != 'DELIVERED')) {
          times[i] = formatDateTime(currentSim);
        } else {
          times[i] = '';
        }
      }
    }
    
    return times;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final done = doneCount(status);
    final header = [
      if ((driverName ?? '').isNotEmpty) 'Driver: $driverName',
      if ((truckNo ?? '').isNotEmpty) 'Truck: $truckNo',
    ].join('  •  ');

    final computedTimes = getTimestamps();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            AppText('Current Trip Status - $tripId',
                style: AppTextStyle.headlineSmall, fontWeight: FontWeight.w800),
            if (header.isNotEmpty) ...[
              const SizedBox(height: 4),
              AppText(header,
                  style: AppTextStyle.labelMedium,
                  color: AppColors.textSecondary),
            ],
            const Divider(height: 24),
          ],
          ...List.generate(stages.length, (i) {
            final isDone = i < done;
            final isCurrent = i == done && status != 'DELIVERED';
            final color = isDone
                ? AppColors.success
                : (isCurrent ? AppColors.info : AppColors.textHint);
            final subtitle = _subtitleFor(i, isDone);
            final timestamp = computedTimes[i];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Time Column
                  SizedBox(
                    width: 76,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AppText(
                        timestamp,
                        style: AppTextStyle.labelMedium,
                        color: isCurrent
                            ? AppColors.info
                            : (isDone
                                ? (isDark ? Colors.white54 : AppColors.textSecondary)
                                : AppColors.textHint),
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Icon Column
                  Column(
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.radio_button_checked_rounded
                                : Icons.circle_outlined),
                        size: 20,
                        color: color,
                      ),
                      if (i != stages.length - 1)
                        Container(
                          width: 2,
                          height: 36,
                          color: isDone
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // 3. Content Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(stages[i],
                              style: AppTextStyle.bodyMedium,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isDone
                                  ? AppColors.success
                                  : (isCurrent
                                      ? AppColors.info
                                      : AppColors.textSecondary)),
                          if (subtitle.isNotEmpty)
                            AppText(subtitle,
                                style: AppTextStyle.labelMedium,
                                color: AppColors.textHint),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
