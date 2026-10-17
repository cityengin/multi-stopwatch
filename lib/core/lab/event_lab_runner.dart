import 'dart:async';

import '../ticker/time_source.dart';
import 'lab_event.dart';

/// Hàm ghi một sự kiện vào kết quả của kịch bản.
typedef LabLog = void Function(String label);

/// Các kịch bản minh họa event loop của Dart, kèm giải thích ngắn cho màn Lab.
///
/// Chữ hiển thị (title, explanation, nhãn sự kiện) viết bằng tiếng Anh để
/// khớp với phần giao diện còn lại của app.
enum LabScenario {
  microtaskVsTimer(
    _microtaskVsTimer,
    title: 'scheduleMicrotask vs Timer',
    explanation:
        'Synchronous code runs to completion first. Then the event loop '
        'drains the whole microtask queue before taking one event (a Timer) '
        'from the event queue, so scheduleMicrotask always runs before '
        'Timer.run even though it was registered later.',
  ),
  futureConstructors(
    _futureConstructors,
    title: 'Ways to create a Future',
    explanation:
        'Future() runs its function on the event queue (a Timer underneath). '
        'Future.microtask runs on the microtask queue. then on an already '
        'completed Future is also a microtask. Future.sync runs its function '
        'immediately, synchronously.',
  ),
  delayedZero(
    _delayedZero,
    title: 'Future.delayed(Duration.zero)',
    explanation:
        'Future.delayed(Duration.zero) does NOT run immediately: it is a 0ms '
        'Timer, so it goes to the event queue, after every microtask and in '
        'registration order with other Timers. Use it to yield to other work '
        '(e.g. let the UI paint); to run as soon as possible after the '
        'current code, use a microtask.',
  ),
  awaitCompletedFuture(
    _awaitCompletedFuture,
    title: 'Awaiting a completed Future',
    explanation:
        'An async function runs synchronously up to its first await, then '
        'returns a Future to the caller. The code after await is a listener '
        'of the awaited Future; if that Future is already complete, the '
        'listener is queued as a microtask right at the await, so it runs '
        'before microtasks scheduled later and before any Timer.',
  ),
  asyncGap(
    _asyncGap,
    title: 'Async gap',
    explanation:
        'Between awaiting an unfinished Future and resuming, other code '
        '(microtasks, Timers, UI events) can run and change state: here '
        'counter goes from 0 to 1. So after await you must check the state '
        'again (in Flutter: mounted, whether the stopwatch still exists). The '
        'code after await runs as soon as the Future completes, i.e. in the '
        'same event turn as the Timer that completed it.',
  ),
  nestedMicrotasks(
    _nestedMicrotasks,
    title: 'Microtasks scheduling microtasks',
    explanation:
        'The event loop only takes the next event once the microtask queue is '
        'empty, including microtasks added while draining it. Consequence: a '
        'very long or endless microtask chain blocks Timers, painting and '
        'input, and the app freezes.',
  );

  const LabScenario(
    this._body, {
    required this.title,
    required this.explanation,
  });

  final void Function(LabLog log) _body;
  final String title;
  final String explanation;
}

/// Chạy thật các kịch bản [LabScenario] và trả về thứ tự thực thi thực tế.
///
/// Vì sao chạy trong một Zone riêng: Zone chặn được `scheduleMicrotask` và
/// `createTimer`, nên mỗi callback được gắn đúng hàng đợi nó thực sự đến từ đó
/// (cột [LabEvent.queue] là đo được, không phải ghi tay theo lý thuyết). Zone
/// cũng đếm số việc đang chờ, nên runner biết chắc khi nào kịch bản chạy xong
/// mà không cần đoán bằng thời gian chờ.
///
/// Giới hạn: kịch bản không được dùng Timer định kỳ hay hủy Timer, vì khi đó
/// số việc đang chờ không bao giờ về 0.
class EventLabRunner {
  EventLabRunner({TimeSource? timeSource})
    : _time = timeSource ?? SystemTimeSource();

  final TimeSource _time;

  /// Chạy [scenario]; Future hoàn thành khi mọi microtask và Timer mà kịch bản
  /// tạo ra đã chạy xong. Các lần chạy độc lập với nhau, kể cả chạy đồng thời.
  Future<List<LabEvent>> run(LabScenario scenario) {
    final events = <LabEvent>[];
    final finished = Completer<List<LabEvent>>();
    final startedAt = _time.monotonicNow();
    var current = LabQueue.sync;
    var pending = 0;
    var syncDone = false;

    void completeIfIdle() {
      if (syncDone && pending == 0 && !finished.isCompleted) {
        finished.complete(List.unmodifiable(events));
      }
    }

    void runFrom(LabQueue queue, void Function() callback) {
      final previous = current;
      current = queue;
      try {
        callback();
      } finally {
        current = previous;
        pending--;
        completeIfIdle();
      }
    }

    void log(String label) => events.add(
      LabEvent(
        sequence: events.length + 1,
        label: label,
        queue: current,
        at: _time.monotonicNow() - startedAt,
      ),
    );

    final zone = Zone.current.fork(
      specification: ZoneSpecification(
        scheduleMicrotask: (self, parent, zone, callback) {
          pending++;
          parent.scheduleMicrotask(
            zone,
            () => runFrom(LabQueue.microtask, callback),
          );
        },
        createTimer: (self, parent, zone, duration, callback) {
          pending++;
          return parent.createTimer(
            zone,
            duration,
            () => runFrom(LabQueue.event, callback),
          );
        },
      ),
    );
    zone.run(() => scenario._body(log));
    syncDone = true;
    completeIfIdle();
    return finished.future;
  }

  /// Chạy lần lượt mọi kịch bản theo thứ tự khai báo.
  Future<Map<LabScenario, List<LabEvent>>> runAll() async => {
    for (final scenario in LabScenario.values) scenario: await run(scenario),
  };
}

void _microtaskVsTimer(LabLog log) {
  log('sync: start');
  Timer.run(() => log('Timer.run'));
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: end');
}

void _futureConstructors(LabLog log) {
  log('sync: start');
  Future(() => log('Future()'));
  Future.microtask(() => log('Future.microtask'));
  Future.value('done').then((_) => log('Future.value().then'));
  Future.sync(() => log('Future.sync'));
  log('sync: end');
}

void _delayedZero(LabLog log) {
  log('sync: start');
  Timer.run(() => log('Timer.run #1'));
  Future<void>.delayed(Duration.zero, () => log('Future.delayed(zero)'));
  Timer.run(() => log('Timer.run #2'));
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: end');
}

void _awaitCompletedFuture(LabLog log) {
  Future<void> worker() async {
    log('worker: before await');
    await Future<void>.value();
    log('worker: after await');
  }

  log('sync: call worker()');
  worker();
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: end');
}

void _asyncGap(LabLog log) {
  var counter = 0;
  Future<void> worker() async {
    log('worker: counter = $counter, await Future.delayed(zero)');
    await Future<void>.delayed(Duration.zero);
    log('worker: after await, counter = $counter');
  }

  worker();
  log('sync: worker is waiting, caller continues');
  scheduleMicrotask(() {
    counter++;
    log('microtask: counter = $counter');
  });
  Timer.run(() {
    counter++;
    log('Timer.run: counter = $counter');
  });
}

void _nestedMicrotasks(LabLog log) {
  Timer.run(() => log('Timer.run'));
  scheduleMicrotask(() {
    log('microtask 1: schedules microtask 2');
    scheduleMicrotask(() => log('microtask 2'));
  });
  log('sync: end');
}
