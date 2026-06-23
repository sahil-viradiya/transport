/// Human-friendly "x ago" formatting for the last-known location timestamp the
/// admin sees. Pure (accepts an optional [now]) so it can be unit-tested.
String timeAgo(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(time);

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
bool isLocationFresh(DateTime time,
    {DateTime? now, Duration window = const Duration(minutes: 30)}) {
  final ref = now ?? DateTime.now();
  return ref.difference(time) <= window && !ref.difference(time).isNegative;
}
