import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/ticker/elapsed_tracker.dart';
import 'package:multi_stopwatch/core/ticker/tick_source.dart';

import '../support/fake_time_sources.dart';

void main() {
  late ManualTimeSource time;

  setUp(() => time = ManualTimeSource());

  group('ElapsedTracker cơ bản', () {
    test('mới tạo thì không chạy và elapsed bằng 0', () {
      final tracker = ElapsedTracker(timeSource: time);
      time.advance(const Duration(seconds: 5));

      expect(tracker.isRunning, isFalse);
      expect(tracker.elapsed, Duration.zero);
      expect(tracker.runningSince, isNull);
    });

    test('start rồi trôi 1.5s thì elapsed đúng 1.5s', () {
      final tracker = ElapsedTracker(timeSource: time);
      final startedAt = time.now();
      tracker.start();
      time.advance(const Duration(milliseconds: 1500));

      expect(tracker.isRunning, isTrue);
      expect(tracker.elapsed, const Duration(milliseconds: 1500));
      expect(tracker.runningSince, startedAt);
    });

    test('stop giữ nguyên giá trị, start lại thì cộng tiếp', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 2));

      expect(tracker.stop(), const Duration(seconds: 2));
      time.advance(const Duration(minutes: 10));
      expect(tracker.elapsed, const Duration(seconds: 2));
      expect(tracker.accumulated, const Duration(seconds: 2));
      expect(tracker.runningSince, isNull);

      tracker.start();
      time.advance(const Duration(seconds: 3));
      expect(tracker.elapsed, const Duration(seconds: 5));
    });

    test('reset về 0 và dừng, kể cả khi đang chạy', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 2));
      tracker
        ..stop()
        ..start();
      time.advance(const Duration(seconds: 1));
      tracker.reset();
      time.advance(const Duration(seconds: 1));

      expect(tracker.isRunning, isFalse);
      expect(tracker.elapsed, Duration.zero);
      expect(tracker.accumulated, Duration.zero);
      expect(tracker.runningSince, isNull);
    });

    test('start khi đang chạy hoặc stop khi đã dừng thì ném StateError', () {
      final tracker = ElapsedTracker(timeSource: time);

      expect(tracker.stop, throwsStateError);
      tracker.start();
      expect(tracker.start, throwsStateError);
    });
  });

  group('không trôi theo tick', () {
    test('chạy 1 giờ có giật (Timer bỏ nhịp): elapsed khớp tuyệt đối, '
        'còn cộng dồn tick lệch hơn 5 phút', () {
      fakeAsync((async) {
        final source = TickSource();
        final tracker = ElapsedTracker(timeSource: FakeAsyncTimeSource(async))
          ..start();
        var callbacks = 0;
        var mismatches = 0;
        var naive = Duration.zero;
        final sub = source.ticks.listen((_) {
          callbacks++;
          naive += TickSource.defaultInterval;
          if (tracker.elapsed != async.elapsed) mismatches++;
          if (callbacks % 90 == 0) {
            async.elapseBlocking(const Duration(milliseconds: 400));
          }
        });
        async.elapse(const Duration(hours: 1));

        expect(mismatches, 0);
        expect(tracker.elapsed, async.elapsed);
        expect(async.elapsed - naive, greaterThan(const Duration(minutes: 5)));
        sub.cancel();
        source.dispose();
      });
    });

    test('tick đến trễ vì event loop bị chặn vẫn đọc ra đúng elapsed', () {
      fakeAsync((async) {
        const interval = Duration(milliseconds: 33);
        final source = TickSource(interval: interval);
        final tracker = ElapsedTracker(timeSource: FakeAsyncTimeSource(async))
          ..start();
        final ticks = <int>[];
        final readings = <Duration>[];
        final actual = <Duration>[];
        final sub = source.ticks.listen((tick) {
          ticks.add(tick);
          readings.add(tracker.elapsed);
          actual.add(async.elapsed);
          if (ticks.length == 5) {
            async.elapseBlocking(const Duration(milliseconds: 500));
          }
        });
        async.elapse(const Duration(milliseconds: 800));

        expect(ticks.take(7), [1, 2, 3, 4, 5, 20, 21]);
        expect(readings, actual);
        expect(readings[5], const Duration(milliseconds: 665));
        expect(readings[5] - interval * 6, const Duration(milliseconds: 467));
        sub.cancel();
        source.dispose();
      });
    });
  });

  group('khôi phục bằng giờ hệ thống', () {
    test('app ở nền lúc máy ngủ: cộng bù phần giờ hệ thống đi trước', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 10));
      time.sleep(const Duration(minutes: 30));
      time.advance(const Duration(seconds: 5));

      expect(tracker.elapsed, const Duration(minutes: 30, seconds: 15));
      time.advance(const Duration(seconds: 1));
      expect(tracker.elapsed, const Duration(minutes: 30, seconds: 16));
    });

    test('stop ngay khi vừa về từ nền vẫn tính cả thời gian máy ngủ', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 3));
      time.sleep(const Duration(minutes: 2));

      expect(tracker.stop(), const Duration(minutes: 2, seconds: 3));
    });

    test('chênh lệch dưới ngưỡng bị bỏ qua nên nhiễu không làm trôi; '
        'không có ngưỡng thì trôi', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      final noThreshold = ElapsedTracker(
        timeSource: time,
        syncThreshold: Duration.zero,
      )..start();
      const reads = 100000;
      for (var i = 0; i < reads; i++) {
        time.advance(const Duration(milliseconds: 33));
        time.shiftWallClock(Duration(microseconds: i.isEven ? 50 : -50));
        tracker.elapsed;
        noThreshold.elapsed;
      }
      const expected = Duration(milliseconds: 33 * reads);

      expect(tracker.elapsed, expected);
      expect(
        noThreshold.elapsed - expected,
        const Duration(milliseconds: 2500),
      );
    });

    test('người dùng chỉnh giờ lùi khi đang chạy: elapsed không đổi, '
        'mốc lưu được dời nên khôi phục vẫn đúng', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 20));
      time.shiftWallClock(const Duration(hours: -1));
      time.advance(const Duration(seconds: 10));

      expect(tracker.elapsed, const Duration(seconds: 30));
      final restored = ElapsedTracker(
        timeSource: ManualTimeSource(wall: time.now()),
        runningSince: tracker.runningSince,
      );
      expect(restored.elapsed, const Duration(seconds: 30));
    });

    test('người dùng chỉnh giờ tiến khi đang chạy: được tính như máy ngủ '
        '(hạn chế đã biết)', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 5));
      time.shiftWallClock(const Duration(hours: 1));

      expect(tracker.elapsed, const Duration(hours: 1, seconds: 5));
    });

    test('khởi động lại khi đang chạy: khôi phục từ runningSince, '
        'cộng cả thời gian app bị tắt', () {
      final tracker = ElapsedTracker(timeSource: time)..start();
      time.advance(const Duration(seconds: 5));
      tracker
        ..stop()
        ..start();
      time.advance(const Duration(seconds: 7));
      final savedAccumulated = tracker.accumulated;
      final savedRunningSince = tracker.runningSince;

      final afterRestart = ManualTimeSource(
        wall: time.now().add(const Duration(minutes: 10)),
      );
      final restored = ElapsedTracker(
        timeSource: afterRestart,
        accumulated: savedAccumulated,
        runningSince: savedRunningSince,
      );

      expect(restored.isRunning, isTrue);
      expect(restored.elapsed, const Duration(minutes: 10, seconds: 12));
      afterRestart.advance(const Duration(seconds: 2));
      expect(restored.elapsed, const Duration(minutes: 10, seconds: 14));
    });

    test('khôi phục đồng hồ đang pause: chỉ có accumulated, không chạy', () {
      final restored = ElapsedTracker(
        timeSource: time,
        accumulated: const Duration(seconds: 42),
      );
      time.advance(const Duration(hours: 1));

      expect(restored.isRunning, isFalse);
      expect(restored.elapsed, const Duration(seconds: 42));
    });

    test('runningSince ở tương lai (giờ bị chỉnh lùi lúc app tắt): '
        'không ra số âm và chạy tiếp từ accumulated', () {
      final restored = ElapsedTracker(
        timeSource: time,
        accumulated: const Duration(seconds: 5),
        runningSince: time.now().add(const Duration(hours: 1)),
      );

      expect(restored.elapsed, const Duration(seconds: 5));
      expect(restored.runningSince, time.now());
      time.advance(const Duration(seconds: 2));
      expect(restored.elapsed, const Duration(seconds: 7));
    });
  });
}
