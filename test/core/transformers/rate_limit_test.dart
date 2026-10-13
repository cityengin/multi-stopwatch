import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/transformers/rate_limit.dart';

const _window = Duration(milliseconds: 300);

/// Ghi lại sự kiện, lỗi và done của một stream kèm thời điểm (ms ảo).
class _Probe<T> {
  _Probe(this._async, Stream<T> stream, {bool cancelOnError = false}) {
    subscription = stream.listen(
      (value) => events.add((value, _now)),
      onError: (Object error) => errors.add((error, _now)),
      onDone: () => doneAt = _now,
      cancelOnError: cancelOnError,
    );
  }

  final FakeAsync _async;
  final events = <(T, int)>[];
  final errors = <(Object, int)>[];
  int? doneAt;
  late final StreamSubscription<T> subscription;

  int get _now => _async.elapsed.inMilliseconds;
}

void _elapseTo(FakeAsync async, int milliseconds) =>
    async.elapse(Duration(milliseconds: milliseconds) - async.elapsed);

/// Đưa [script] vào [source]: mỗi phần tử là (thời điểm ms, giá trị).
void _play(
  FakeAsync async,
  StreamController<String> source,
  List<(int, String)> script,
) {
  for (final (at, value) in script) {
    _elapseTo(async, at);
    source.add(value);
  }
}

const _burst = [(0, 'a'), (100, 'b'), (200, 'c'), (700, 'd'), (800, 'e')];

void main() {
  group('ThrottleTransformer', () {
    test('phát ngay sự kiện đầu, bỏ các sự kiện đến trong cửa sổ', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.throttled(_window));
        _play(async, source, _burst);
        _elapseTo(async, 2000);

        expect(probe.events, [('a', 0), ('d', 700)]);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('trailing: giữ sự kiện cuối trong cửa sổ, phát khi cửa sổ đóng', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(
          async,
          source.stream.throttled(_window, trailing: true),
        );
        _play(async, source, _burst);
        _elapseTo(async, 2000);

        expect(probe.events, [('a', 0), ('c', 300), ('d', 700), ('e', 1000)]);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('nguồn phát liên tục: tối đa một sự kiện mỗi cửa sổ, '
        'trailing giữ được giá trị cuối', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(
          async,
          source.stream.throttled(_window, trailing: true),
        );
        _play(async, source, [for (var i = 0; i < 20; i++) (i * 50, '$i')]);
        _elapseTo(async, 3000);

        expect(probe.events.map((e) => e.$2), [0, 300, 600, 900, 1200]);
        expect(probe.events.last.$1, '19');
      });
    });

    test('nguồn done: không có trailing thì done ngay và hủy cửa sổ', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.throttled(_window));
        _play(async, source, [(0, 'a'), (100, 'b')]);
        _elapseTo(async, 150);
        source.close();
        async.flushMicrotasks();

        expect(probe.events, [('a', 0)]);
        expect(probe.doneAt, 150);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('nguồn done khi trailing đang giữ: phát ngay rồi mới done', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(
          async,
          source.stream.throttled(_window, trailing: true),
        );
        _play(async, source, [(0, 'a'), (100, 'b')]);
        _elapseTo(async, 150);
        source.close();
        async.flushMicrotasks();

        expect(probe.events, [('a', 0), ('b', 150)]);
        expect(probe.doneAt, 150);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('lỗi được chuyển ngay và không ảnh hưởng cửa sổ', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.throttled(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 100);
        source.addError('lỗi');
        _play(async, source, [(200, 'b'), (400, 'c')]);
        _elapseTo(async, 1000);

        expect(probe.errors, [('lỗi', 100)]);
        expect(probe.events, [('a', 0), ('c', 400)]);
      });
    });

    test('cancel: hủy cửa sổ đang mở và subscription nguồn', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(
          async,
          source.stream.throttled(_window, trailing: true),
        );
        _play(async, source, [(0, 'a'), (100, 'b')]);
        probe.subscription.cancel();
        async.flushMicrotasks();

        expect(source.hasListener, isFalse);
        expect(async.pendingTimers, isEmpty);
        _elapseTo(async, 1000);
        expect(probe.events, [('a', 0)]);
      });
    });

    test('pause lan ngược về nguồn; resume thì nhận tiếp', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.throttled(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 50);
        probe.subscription.pause();
        expect(source.isPaused, isTrue);

        _play(async, source, [(100, 'b')]);
        _elapseTo(async, 1000);
        expect(probe.events, [('a', 0)]);
        probe.subscription.resume();
        async.flushMicrotasks();

        expect(source.isPaused, isFalse);
        expect(probe.events, [('a', 0), ('b', 1000)]);
      });
    });

    test('broadcast: đầu ra broadcast, mọi listener nhận như nhau; hết '
        'listener thì dọn dẹp, listen lại thì bắt đầu lại', () {
      fakeAsync((async) {
        final source = StreamController<String>.broadcast();
        final throttled = source.stream.throttled(_window);
        expect(throttled.isBroadcast, isTrue);
        final first = _Probe(async, throttled);
        final second = _Probe(async, throttled);
        _play(async, source, [(0, 'a'), (100, 'b'), (400, 'c')]);
        async.flushMicrotasks();

        expect(first.events, [('a', 0), ('c', 400)]);
        expect(second.events, first.events);
        first.subscription.cancel();
        second.subscription.cancel();
        async.flushMicrotasks();
        expect(source.hasListener, isFalse);
        expect(async.pendingTimers, isEmpty);

        final again = _Probe(async, throttled);
        _play(async, source, [(500, 'd')]);
        async.flushMicrotasks();
        expect(again.events, [('d', 500)]);
        again.subscription.cancel();
      });
    });
  });

  group('DebounceTransformer', () {
    test('chỉ phát sự kiện cuối sau khi nguồn im lặng đủ duration', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, _burst);
        _elapseTo(async, 2000);

        expect(probe.events, [('c', 500), ('e', 1100)]);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('nguồn phát liên tục thì không phát gì cho tới khi im lặng', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [for (var i = 0; i < 20; i++) (i * 100, '$i')]);

        expect(probe.events, isEmpty);
        _elapseTo(async, 3000);
        expect(probe.events, [('19', 2200)]);
      });
    });

    test('nguồn done: phát ngay sự kiện đang chờ rồi mới done', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 100);
        source.close();
        async.flushMicrotasks();

        expect(probe.events, [('a', 100)]);
        expect(probe.doneAt, 100);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('nguồn done khi không có gì đang chờ: done ngay', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 500);
        source.close();
        async.flushMicrotasks();

        expect(probe.events, [('a', 300)]);
        expect(probe.doneAt, 500);
      });
    });

    test('lỗi được chuyển ngay, không làm mất sự kiện đang chờ', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 100);
        source.addError('lỗi');
        _elapseTo(async, 1000);

        expect(probe.errors, [('lỗi', 100)]);
        expect(probe.events, [('a', 300)]);
      });
    });

    test('cancel: hủy Timer đang chờ và subscription nguồn', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 100);
        probe.subscription.cancel();
        async.flushMicrotasks();

        expect(source.hasListener, isFalse);
        expect(async.pendingTimers, isEmpty);
        _elapseTo(async, 1000);
        expect(probe.events, isEmpty);
      });
    });

    test(
      'listener cancelOnError: lỗi làm hủy ngay Timer đang chờ và nguồn',
      () {
        fakeAsync((async) {
          final source = StreamController<String>();
          final probe = _Probe(
            async,
            source.stream.debounced(_window),
            cancelOnError: true,
          );
          _play(async, source, [(0, 'a')]);
          _elapseTo(async, 100);
          source.addError('lỗi');
          async.flushMicrotasks();

          expect(source.hasListener, isFalse);
          expect(async.pendingTimers, isEmpty);
          _elapseTo(async, 1000);
          expect(probe.events, isEmpty);
        });
      },
    );

    test('listener cancelOnError vẫn nhận được lỗi '
        '(chạy async thật vì SDK giao lỗi sau khi hủy nguồn xong)', () async {
      final source = StreamController<String>();
      final received = Completer<Object>();
      source.stream
          .debounced(_window)
          .listen(
            (_) {},
            onError: (Object error) => received.complete(error),
            cancelOnError: true,
          );
      source
        ..add('a')
        ..addError('lỗi');

      expect(await received.future, 'lỗi');
      expect(source.hasListener, isFalse);
    });

    test('pause lan ngược về nguồn; giá trị Timer phát lúc pause được giữ '
        'tới khi resume', () {
      fakeAsync((async) {
        final source = StreamController<String>();
        final probe = _Probe(async, source.stream.debounced(_window));
        _play(async, source, [(0, 'a')]);
        _elapseTo(async, 100);
        probe.subscription.pause();
        expect(source.isPaused, isTrue);

        _elapseTo(async, 1000);
        expect(probe.events, isEmpty);
        expect(async.pendingTimers, isEmpty);
        probe.subscription.resume();
        async.flushMicrotasks();

        expect(source.isPaused, isFalse);
        expect(probe.events, [('a', 1000)]);
      });
    });

    test('broadcast: đầu ra broadcast, mọi listener nhận như nhau; hết '
        'listener thì dọn dẹp, listen lại thì bắt đầu lại', () {
      fakeAsync((async) {
        final source = StreamController<String>.broadcast();
        final debounced = source.stream.debounced(_window);
        expect(debounced.isBroadcast, isTrue);
        final first = _Probe(async, debounced);
        final second = _Probe(async, debounced);
        _play(async, source, [(0, 'a'), (100, 'b')]);
        _elapseTo(async, 500);

        expect(first.events, [('b', 400)]);
        expect(second.events, first.events);
        _play(async, source, [(600, 'c')]);
        first.subscription.cancel();
        second.subscription.cancel();
        async.flushMicrotasks();
        expect(source.hasListener, isFalse);
        expect(async.pendingTimers, isEmpty);

        final again = _Probe(async, debounced);
        _play(async, source, [(700, 'd')]);
        _elapseTo(async, 1500);
        expect(again.events, [('d', 1000)]);
        again.subscription.cancel();
      });
    });

    test(
      'một transformer dùng cho nhiều stream: trạng thái không lẫn nhau',
      () {
        fakeAsync((async) {
          final transformer = DebounceTransformer<String>(_window);
          final left = StreamController<String>();
          final right = StreamController<String>();
          final leftProbe = _Probe(async, left.stream.transform(transformer));
          final rightProbe = _Probe(async, right.stream.transform(transformer));
          _play(async, left, [(0, 'a')]);
          _play(async, right, [(100, 'x')]);
          _elapseTo(async, 1000);

          expect(leftProbe.events, [('a', 300)]);
          expect(rightProbe.events, [('x', 400)]);
        });
      },
    );
  });
}
