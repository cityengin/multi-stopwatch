import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/debug/stream_tracker.dart';
import 'package:multi_stopwatch/core/ticker/tick_source.dart';

import '../support/fake_time_sources.dart';

const _interval = Duration(milliseconds: 100);

void main() {
  group('TickSource', () {
    test('chưa có listener thì không tạo Timer', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        async.elapse(const Duration(seconds: 1));

        expect(source.isTicking, isFalse);
        expect(async.periodicTimerCount, 0);
        source.dispose();
      });
    });

    test('nhiều listener cùng nhận tick từ một Timer duy nhất', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        final a = <int>[];
        final b = <int>[];
        final c = <int>[];
        final subA = source.ticks.listen(a.add);
        final subB = source.ticks.listen(b.add);
        final subC = source.ticks.listen(c.add);

        expect(async.periodicTimerCount, 1);
        async.elapse(const Duration(milliseconds: 350));

        expect(a, [1, 2, 3]);
        expect(b, [1, 2, 3]);
        expect(c, [1, 2, 3]);
        subA.cancel();
        subB.cancel();
        subC.cancel();
        source.dispose();
      });
    });

    test('listener vào sau chỉ nhận tick từ lúc vào', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        final early = <int>[];
        final late = <int>[];
        final subEarly = source.ticks.listen(early.add);
        async.elapse(const Duration(milliseconds: 250));
        final subLate = source.ticks.listen(late.add);
        async.elapse(const Duration(milliseconds: 200));

        expect(early, [1, 2, 3, 4]);
        expect(late, [3, 4]);
        expect(async.periodicTimerCount, 1);
        subEarly.cancel();
        subLate.cancel();
        source.dispose();
      });
    });

    test('một listener hủy thì listener còn lại vẫn nhận tick', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        final kept = <int>[];
        final dropped = <int>[];
        final subKept = source.ticks.listen(kept.add);
        final subDropped = source.ticks.listen(dropped.add);
        async.elapse(const Duration(milliseconds: 150));
        subDropped.cancel();
        async.elapse(const Duration(milliseconds: 200));

        expect(dropped, [1]);
        expect(kept, [1, 2, 3]);
        expect(source.isTicking, isTrue);
        subKept.cancel();
        source.dispose();
      });
    });

    test('hết listener thì Timer dừng', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        final received = <int>[];
        final sub1 = source.ticks.listen(received.add);
        final sub2 = source.ticks.listen((_) {});
        async.elapse(const Duration(milliseconds: 250));
        sub1.cancel();
        sub2.cancel();
        async.flushMicrotasks();

        expect(source.isTicking, isFalse);
        expect(async.periodicTimerCount, 0);
        async.elapse(const Duration(seconds: 1));
        expect(received, [1, 2]);
        source.dispose();
      });
    });

    test('listen lại sau khi dừng thì Timer chạy lại, đếm tick từ đầu', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        final first = <int>[];
        final second = <int>[];
        final sub1 = source.ticks.listen(first.add);
        async.elapse(const Duration(milliseconds: 250));
        sub1.cancel();
        async.elapse(const Duration(seconds: 1));

        final sub2 = source.ticks.listen(second.add);
        expect(source.isTicking, isTrue);
        expect(async.periodicTimerCount, 1);
        async.elapse(const Duration(milliseconds: 350));

        expect(first, [1, 2]);
        expect(second, [1, 2, 3]);
        sub2.cancel();
        source.dispose();
      });
    });

    test('chu kỳ mặc định là 33ms', () {
      fakeAsync((async) {
        final source = TickSource();
        final received = <int>[];
        final sub = source.ticks.listen(received.add);
        async.elapse(const Duration(milliseconds: 330));

        expect(TickSource.defaultInterval, const Duration(milliseconds: 33));
        expect(source.interval, TickSource.defaultInterval);
        expect(received, hasLength(10));
        sub.cancel();
        source.dispose();
      });
    });

    test('dispose dừng Timer, listener nhận done, gọi lại trả cùng Future', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        var done = false;
        source.ticks.listen((_) {}, onDone: () => done = true);
        async.elapse(const Duration(milliseconds: 150));

        final first = source.dispose();
        final second = source.dispose();
        async.flushMicrotasks();

        expect(identical(first, second), isTrue);
        expect(done, isTrue);
        expect(source.isTicking, isFalse);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('listen sau dispose nhận done ngay và không tạo Timer', () {
      fakeAsync((async) {
        final source = TickSource(interval: _interval);
        source.dispose();
        async.flushMicrotasks();

        var done = false;
        final received = <int>[];
        source.ticks.listen(received.add, onDone: () => done = true);
        async.elapse(const Duration(seconds: 1));

        expect(done, isTrue);
        expect(received, isEmpty);
        expect(source.isTicking, isFalse);
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  group('TickSource với StreamTracker', () {
    test('mỗi listener của ticks được đếm; hết listener thì về 0 và Timer '
        'dừng', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final source = TickSource(interval: _interval, tracker: tracker);
        final first = source.ticks.listen((_) {});
        final second = source.ticks.listen((_) {});

        expect(tracker.activeBySource, {'TickSource.ticks': 2});
        expect(source.hasListener, isTrue);
        async.elapse(_interval * 2);
        first.cancel();
        second.cancel();
        async.flushMicrotasks();

        expect(tracker.activeCount, 0);
        expect(source.hasListener, isFalse);
        expect(source.isTicking, isFalse);
        expect(async.periodicTimerCount, 0);
        source.dispose();
      });
    });

    test('dispose: listener nhận done, hasListener == false, không còn Timer, '
        'số subscription về 0, log có dispose', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final source = TickSource(interval: _interval, tracker: tracker);
        var done = false;
        source.ticks.listen((_) {}, onDone: () => done = true);
        async.elapse(_interval * 3);

        source.dispose();
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(source.hasListener, isFalse);
        expect(source.isTicking, isFalse);
        expect(async.pendingTimers, isEmpty);
        expect(tracker.activeCount, 0);
        expect(
          [for (final e in tracker.history) (e.kind, e.source, e.activeCount)],
          [
            (StreamLogKind.listen, 'TickSource.ticks', 1),
            (StreamLogKind.done, 'TickSource.ticks', 0),
            (StreamLogKind.dispose, 'TickSource', 0),
          ],
        );
      });
    });
  });
}
