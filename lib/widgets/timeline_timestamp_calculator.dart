import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/core/utils/time_utils.dart';

/// Helper to calculate timestamps for each milestone stage in the trip timeline.
class TimelineTimestampCalculator {
  TimelineTimestampCalculator._();

  static String calculateTimestamp(int index, List<dynamic>? milestonesLog) {
    if (milestonesLog == null || milestonesLog.isEmpty) return '';

    final stageMilestoneMap = {
      0: 1, // Stage 1 -> Assigned / Start
      1: 2, // Stage 2 -> Reached Loading
      2: 3, // Stage 3 -> Loaded & Approved
      3: 4, // Stage 4 -> Delivered
    };

    final targetMilestone = stageMilestoneMap[index];
    if (targetMilestone == null) return '';

    for (final log in milestonesLog) {
      if (log is Map) {
        final m = log['milestone'];
        if (m == targetMilestone) {
          final ts = log['timestamp'];
          if (ts != null) {
            if (ts is Timestamp) return timeAgo(ts.toDate());
            if (ts is DateTime) return timeAgo(ts);
            if (ts is String) return timeAgo(ts);
          }
        }
      }
    }
    return '';
  }
}
