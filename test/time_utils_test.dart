import 'package:flutter_test/flutter_test.dart';
import 'package:transport/app/core/utils/time_utils.dart';

void main() {
  final now = DateTime(2026, 6, 19, 12, 0, 0);

  group('timeAgo', () {
    test('treats very recent times as "just now"', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
      expect(timeAgo(now.add(const Duration(minutes: 5)), now: now), 'just now');
    });

    test('formats minutes', () {
      expect(timeAgo(now.subtract(const Duration(minutes: 10)), now: now), '10 min ago');
    });

    test('formats hours', () {
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 hr ago');
    });

    test('formats days with pluralisation', () {
      expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2 days ago');
    });
  });

  group('isLocationFresh', () {
    test('recent location is fresh', () {
      expect(isLocationFresh(now.subtract(const Duration(minutes: 5)), now: now), true);
    });

    test('stale location is not fresh', () {
      expect(isLocationFresh(now.subtract(const Duration(hours: 2)), now: now), false);
    });
  });
}
