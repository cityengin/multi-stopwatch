import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/debug/stream_tracker.dart';

import '../support/fake_time_sources.dart';

List<(StreamLogKind, String, int)> _rows(Iterable<StreamLogEvent> events) => [
  for (final event in events) (event.kind, event.source, event.activeCount),
];

void main() {
  group('StreamTracker', () {
    test('listen tăng, cancel giảm số subscription; log ghi kèm số active và '
        'thời điểm', () {
      fakeAsync((async) {
        final time = FakeAsyncTimeSource(async);
        final tracker = StreamTracker(timeSource: time);
        final log = <StreamLogEvent>[];
        tracker.events.listen(log.add);
        final source = StreamController<int>.broadcast();
        final tracked = tracker.track('nguồn', source.stream);

        final first = tracked.listen((_) {});
        final second = tracked.listen((_) {});
        expect(tracker.activeCount, 2);
        expect(tracker.activeBySource, {'nguồn': 2});
        async.elapse(const Duration(seconds: 1));
        first.cancel();
        expect(tracker.activeCount, 1);
        second.cancel();
        async.flushMicrotasks();

        expect(tracker.activeCount, 0);
        expect(tracker.activeBySource, isEmpty);
        expect(source.hasListener, isFalse);
        expect(_rows(log), [
          (StreamLogKind.listen, 'nguồn', 1),
          (StreamLogKind.listen, 'nguồn', 2),
          (StreamLogKind.cancel, 'nguồn', 1),
          (StreamLogKind.cancel, 'nguồn', 0),
        ]);
        expect(log.first.at, time.now().subtract(const Duration(seconds: 1)));
        expect(log.last.at, time.now());
        tracker.dispose();
      });
    });

    test('stream done thì subscription được tính là kết thúc (done)', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final source = StreamController<int>();
        var done = false;
        tracker
            .track('một lần', source.stream)
            .listen((_) {}, onDone: () => done = true);
        source.close();
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(tracker.activeCount, 0);
        expect(_rows(tracker.history), [
          (StreamLogKind.listen, 'một lần', 1),
          (StreamLogKind.done, 'một lần', 0),
        ]);
      });
    });

    test('dữ liệu và lỗi được chuyển nguyên vẹn; pause/resume lan về nguồn; '
        'giữ nguyên tính broadcast', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final source = StreamController<int>();
        final values = <int>[];
        final errors = <Object>[];
        final tracked = tracker.track('dữ liệu', source.stream);
        final subscription = tracked.listen(values.add, onError: errors.add);
        source
          ..add(1)
          ..addError('lỗi')
          ..add(2);
        async.flushMicrotasks();
        expect(values, [1, 2]);
        expect(errors, ['lỗi']);

        subscription.pause();
        expect(source.isPaused, isTrue);
        source.add(3);
        async.flushMicrotasks();
        expect(values, [1, 2]);
        subscription.resume();
        async.flushMicrotasks();
        expect(values, [1, 2, 3]);
        expect(source.isPaused, isFalse);

        expect(tracked.isBroadcast, isFalse);
        expect(
          tracker
              .track('b', StreamController<int>.broadcast().stream)
              .isBroadcast,
          isTrue,
        );
        subscription.cancel();
      });
    });

    test('cancelOnError: lỗi làm subscription kết thúc, số đếm giảm ngay', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final source = StreamController<int>();
        tracker
            .track('lỗi', source.stream)
            .listen((_) {}, onError: (Object _) {}, cancelOnError: true);
        source.addError('lỗi');
        async.flushMicrotasks();

        expect(tracker.activeCount, 0);
        expect(source.hasListener, isFalse);
        expect(_rows(tracker.history).last, (StreamLogKind.cancel, 'lỗi', 0));
      });
    });

    test('đếm riêng theo từng luồng', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final a = tracker.track('a', StreamController<int>.broadcast().stream);
        final b = tracker.track('b', StreamController<int>().stream);
        final subscriptions = [
          a.listen((_) {}),
          a.listen((_) {}),
          b.listen((_) {}),
        ];

        expect(tracker.activeBySource, {'a': 2, 'b': 1});
        expect(tracker.activeCount, 3);
        subscriptions.first.cancel();
        expect(tracker.activeBySource, {'a': 1, 'b': 1});
        for (final subscription in subscriptions.skip(1)) {
          subscription.cancel();
        }
        expect(tracker.activeBySource, isEmpty);
      });
    });

    test('history chỉ giữ historyLimit sự kiện gần nhất và không sửa được', () {
      fakeAsync((async) {
        final tracker = StreamTracker(
          timeSource: FakeAsyncTimeSource(async),
          historyLimit: 3,
        );
        final source = StreamController<int>.broadcast();
        for (var i = 0; i < 3; i++) {
          tracker.track('s$i', source.stream).listen((_) {}).cancel();
        }

        expect(_rows(tracker.history), [
          (StreamLogKind.cancel, 's1', 0),
          (StreamLogKind.listen, 's2', 1),
          (StreamLogKind.cancel, 's2', 0),
        ]);
        expect(
          () => tracker.history.add(tracker.history.first),
          throwsUnsupportedError,
        );
      });
    });

    test('recordDispose ghi sự kiện dispose của một thành phần', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        final log = <StreamLogEvent>[];
        tracker.events.listen(log.add);
        tracker.recordDispose('TickSource');
        async.flushMicrotasks();

        expect(_rows(log), [(StreamLogKind.dispose, 'TickSource', 0)]);
      });
    });

    test('dispose: đóng log, gọi nhiều lần được; sau đó vẫn đếm đúng nhưng '
        'không phát log nữa', () {
      fakeAsync((async) {
        final tracker = StreamTracker(timeSource: FakeAsyncTimeSource(async));
        var logDone = false;
        tracker.events.listen((_) {}, onDone: () => logDone = true);
        final first = tracker.dispose();
        final second = tracker.dispose();
        async.flushMicrotasks();

        expect(identical(first, second), isTrue);
        expect(logDone, isTrue);
        final subscription = tracker
            .track('sau', StreamController<int>.broadcast().stream)
            .listen((_) {});
        expect(tracker.activeCount, 1);
        expect(tracker.history, isEmpty);
        subscription.cancel();
        expect(tracker.activeCount, 0);
      });
    });
  });
}
