import 'package:flutter_test/flutter_test.dart';
import 'package:transport/app/data/services/location_service.dart';

void main() {
  final svc = LocationService();

  group('estimateTravelTime', () {
    test('returns 0 mins for non-positive distance', () {
      expect(svc.estimateTravelTime(0), '0 mins');
      expect(svc.estimateTravelTime(-10), '0 mins');
    });

    test('formats sub-hour trips in minutes only', () {
      // 27.5 km @ 55 km/h = 0.5 h = 30 mins
      expect(svc.estimateTravelTime(27.5), '30 mins');
    });

    test('formats multi-hour trips as h m', () {
      // 110 km @ 55 km/h = 2h 0m
      expect(svc.estimateTravelTime(110), '2h 0m');
    });

    test('honours a custom average speed', () {
      // 60 km @ 60 km/h = 1h 0m
      expect(svc.estimateTravelTime(60, averageSpeedKmh: 60), '1h 0m');
    });
  });
}
