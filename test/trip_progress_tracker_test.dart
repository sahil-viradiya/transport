import 'package:flutter_test/flutter_test.dart';
import 'package:transport/widgets/trip_progress_tracker.dart';

void main() {
  group('TripProgressTracker.stageOf', () {
    test('a freshly assigned trip with no log is stage 1', () {
      expect(TripProgressTracker.stageOf({'status': 'ASSIGNED'}), 1);
    });

    test('derives the stage from the highest milestone in the log', () {
      final trip = {
        'status': 'ACTIVE NOW',
        'milestonesLog': [
          {'milestone': 1, 'label': 'Trip Assigned', 'address': 'Aslali'},
          {'milestone': 2, 'label': 'Reached Pickup', 'address': 'JNPT'},
        ],
      };
      expect(TripProgressTracker.stageOf(trip), 2);
    });

    test('falls back to the currentMilestone scalar when no log exists', () {
      expect(TripProgressTracker.stageOf({'currentMilestone': 3}), 3);
    });

    test('DELIVERED status forces stage 4 even without a complete log', () {
      expect(TripProgressTracker.stageOf({'status': 'DELIVERED'}), 4);
    });

    test('clamps out-of-range milestones into 1..4', () {
      expect(TripProgressTracker.stageOf({'currentMilestone': 0}), 1);
      expect(TripProgressTracker.stageOf({'currentMilestone': 9}), 4);
    });
  });

  group('TripProgressTracker.lastCheckpointOf', () {
    test('returns null when there is no milestone history', () {
      expect(TripProgressTracker.lastCheckpointOf({'status': 'ASSIGNED'}), isNull);
    });

    test('returns the most advanced checkpoint regardless of array order', () {
      final trip = {
        'milestonesLog': [
          {'milestone': 3, 'label': 'Loaded', 'address': 'JNPT', 'timestamp': '11:30'},
          {'milestone': 1, 'label': 'Trip Assigned', 'address': 'Aslali'},
          {'milestone': 2, 'label': 'Reached Pickup', 'address': 'JNPT Gate'},
        ],
      };
      final last = TripProgressTracker.lastCheckpointOf(trip)!;
      expect(last['milestone'], 3);
      expect(last['address'], 'JNPT');
      expect(last['timestamp'], '11:30');
    });
  });
}
