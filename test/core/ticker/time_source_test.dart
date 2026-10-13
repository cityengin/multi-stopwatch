import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/ticker/elapsed_tracker.dart';
import 'package:multi_stopwatch/core/ticker/time_source.dart';

void main() {
  group('SystemTimeSource', () {
    test('now() trả về giờ UTC', () {
      expect(SystemTimeSource().now().isUtc, isTrue);
    });

    test('monotonicNow() không bao giờ giảm', () {
      final source = SystemTimeSource();
      var previous = source.monotonicNow();
      for (var i = 0; i < 1000; i++) {
        final current = source.monotonicNow();
        expect(current >= previous, isTrue);
        previous = current;
      }
    });

    test('ElapsedTracker không inject thì dùng SystemTimeSource', () {
      final tracker = ElapsedTracker()..start();

      expect(tracker.isRunning, isTrue);
      expect(tracker.elapsed.isNegative, isFalse);
      expect(tracker.runningSince!.isUtc, isTrue);
    });
  });
}
