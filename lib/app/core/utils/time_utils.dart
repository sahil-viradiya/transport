import 'package:cloud_firestore/cloud_firestore.dart';

/// Safely parses any date representation (DateTime, Timestamp, String, int) into a DateTime.
DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

/// Human-friendly "x ago" formatting. Accepts DateTime, Timestamp, String, int, or null.
String timeAgo(dynamic time, {DateTime? now}) {
  final dt = parseDateTime(time);
  if (dt == null) return '';

  final ref = now ?? DateTime.now();
  final diff = ref.difference(dt);

  if (diff.isNegative || diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m min ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hr ago';
  }
  final d = diff.inDays;
  return '$d day${d == 1 ? '' : 's'} ago';
}

/// Whether a location captured at [time] is recent enough to be trusted as the
/// truck's "current" position (defaults to within the last 30 minutes).
bool isLocationFresh(dynamic time,
    {DateTime? now, Duration window = const Duration(minutes: 30)}) {
  final dt = parseDateTime(time);
  if (dt == null) return false;

  final ref = now ?? DateTime.now();
  return ref.difference(dt) <= window && !ref.difference(dt).isNegative;
}
