import 'package:flutter/material.dart';
import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

/// Shows how far a truck has progressed on its trip, derived purely from the
/// discrete milestone checkpoints the driver reports (Assigned → Reached Pickup
/// → Loaded → Delivered). No live GPS required — it answers "mera truck abhi
/// kaha pahucha?" using the last checkpoint the driver marked, with its location
/// and time.
class TripProgressTracker extends StatelessWidget {
  final Map<String, dynamic> trip;

  /// Compact = a single-line stepper for list cards. Full = stepper + a
  /// "last checkpoint" summary panel for detail views.
  final bool showSummary;

  const TripProgressTracker({
    super.key,
    required this.trip,
    this.showSummary = true,
  });

  static const List<String> _stageLabels = [
    'Assigned',
    'Pickup',
    'Loaded',
    'Delivered',
  ];

  /// 1..4 — the highest checkpoint the truck has reached. Pure + testable.
  /// Prefers the milestone log (the driver appends to it), then the
  /// `currentMilestone` scalar, then a DELIVERED status.
  static int stageOf(Map<String, dynamic> trip) {
    var stage = 0;

    for (final e in logEntriesOf(trip)) {
      final m = (e['milestone'] as num?)?.toInt() ?? 0;
      if (m > stage) stage = m;
    }

    final cm = (trip['currentMilestone'] as num?)?.toInt() ?? 0;
    if (cm > stage) stage = cm;

    if ((trip['status'] ?? '') == 'DELIVERED' && stage < 4) stage = 4;
    if (stage < 1) stage = 1;
    if (stage > 4) stage = 4;
    return stage;
  }

  static List<Map<String, dynamic>> logEntriesOf(Map<String, dynamic> trip) {
    final raw = trip['milestonesLog'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  /// The most advanced checkpoint reached (label + address + timestamp).
  static Map<String, dynamic>? lastCheckpointOf(Map<String, dynamic> trip) {
    final log = logEntriesOf(trip);
    if (log.isEmpty) return null;
    log.sort((a, b) => ((a['milestone'] as num?)?.toInt() ?? 0)
        .compareTo((b['milestone'] as num?)?.toInt() ?? 0));
    return log.last;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stage = stageOf(trip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepper(stage, isDark),
        if (showSummary) ...[
          const SizedBox(height: 12),
          _buildSummary(context, stage, isDark),
        ],
      ],
    );
  }

  Widget _buildStepper(int stage, bool isDark) {
    // Stage 4 = delivered = the whole trip is complete, so the final node is a
    // green tick (done), not the amber "currently here" marker.
    final complete = stage >= 4;
    final children = <Widget>[];
    for (var i = 0; i < _stageLabels.length; i++) {
      final stepNo = i + 1;
      final done = stepNo < stage || (stepNo == stage && complete);
      final current = stepNo == stage && !complete;

      children.add(_buildNode(stepNo, _stageLabels[i], done, current, isDark));
      if (i != _stageLabels.length - 1) {
        // Connector line, vertically centred against the 28px circle nodes.
        children.add(Expanded(
          child: SizedBox(
            height: 28,
            child: Center(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: stepNo < stage
                      ? AppColors.success
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildNode(
      int stepNo, String label, bool done, bool current, bool isDark) {
    final Color bg;
    final Widget inner;
    if (done) {
      bg = AppColors.success;
      inner = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
    } else if (current) {
      bg = AppColors.tertiaryDark; // amber = "currently here"
      inner = const Icon(Icons.local_shipping_rounded,
          color: Colors.white, size: 15);
    } else {
      bg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      inner = AppText('$stepNo',
          style: AppTextStyle.labelMedium,
          color: isDark ? Colors.white54 : AppColors.textHint,
          fontWeight: FontWeight.bold);
    }

    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: inner,
          ),
          const SizedBox(height: 6),
          AppText(
            label,
            style: AppTextStyle.labelMedium,
            textAlign: TextAlign.center,
            color: current
                ? AppColors.tertiaryDark
                : (done
                    ? AppColors.success
                    : (isDark ? Colors.white54 : AppColors.textHint)),
            fontWeight: current ? FontWeight.bold : FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, int stage, bool isDark) {
    final checkpoint = lastCheckpointOf(trip);
    final dropCity = (trip['dropCity'] ?? '').toString();
    final dropLoc = (trip['dropLocation'] ?? '').toString();
    final pickupLoc = (trip['pickupLocation'] ?? '').toString();

    // Headline = honest, milestone-based "where it reached".
    String headline;
    IconData icon;
    Color tint;
    switch (stage) {
      case 4:
        icon = Icons.flag_rounded;
        tint = AppColors.success;
        headline = 'Delivered${dropLoc.isNotEmpty ? ' at $dropLoc' : ''}';
        break;
      case 3:
        icon = Icons.local_shipping_rounded;
        tint = AppColors.tertiaryDark;
        headline =
            'Loaded — en route${dropCity.isNotEmpty ? ' to $dropCity' : ''}';
        break;
      case 2:
        icon = Icons.warehouse_rounded;
        tint = AppColors.primary;
        headline = 'Reached pickup${pickupLoc.isNotEmpty ? ' • $pickupLoc' : ''}';
        break;
      default:
        icon = Icons.schedule_rounded;
        tint = AppColors.textSecondary;
        headline = 'Assigned — yet to reach pickup';
    }

    final address = (checkpoint?['address'] ?? '').toString();
    final timestamp = (checkpoint?['timestamp'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(headline,
                    style: AppTextStyle.bodyMedium,
                    color: tint,
                    fontWeight: FontWeight.bold),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText('Last checkpoint: $address',
                      style: AppTextStyle.labelMedium,
                      color: isDark ? Colors.white70 : AppColors.secondary),
                ],
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText('Updated: $timestamp',
                      style: AppTextStyle.labelMedium,
                      color: isDark ? Colors.white38 : AppColors.textHint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
