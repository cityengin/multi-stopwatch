import 'dart:async';

import '../ticker/time_source.dart';
import 'lab_event.dart';

/// Hàm ghi một sự kiện vào kết quả của kịch bản.
typedef LabLog = void Function(String label);

/// Các kịch bản minh họa event loop của Dart, kèm giải thích ngắn cho màn Lab.
enum LabScenario {
  microtaskVsTimer(
    _microtaskVsTimer,
    title: 'scheduleMicrotask và Timer',
    explanation:
        'Mã đồng bộ chạy hết trước. Sau đó event loop xả sạch hàng đợi '
        'microtask rồi mới lấy một sự kiện (Timer) từ hàng đợi event, nên '
        'scheduleMicrotask luôn chạy trước Timer.run dù được đăng ký sau.',
  ),
  futureConstructors(
    _futureConstructors,
    title: 'Các cách tạo Future',
    explanation:
        'Future() chạy hàm ở hàng đợi event (bên dưới là một Timer). '
        'Future.microtask chạy ở hàng đợi microtask. then của một Future đã '
        'hoàn thành cũng là microtask. Future.sync chạy hàm ngay lập tức, '
        'đồng bộ.',
  ),
  delayedZero(
    _delayedZero,
    title: 'Future.delayed(Duration.zero)',
    explanation:
        'Future.delayed(Duration.zero) KHÔNG chạy ngay: nó là một Timer 0ms '
        'nên vào hàng đợi event, đứng sau mọi microtask và theo đúng thứ tự '
        'đăng ký với các Timer khác. Dùng nó để nhường cho việc khác (vd UI '
        'vẽ xong); muốn chạy sớm nhất sau mã hiện tại thì dùng microtask.',
  ),
  awaitCompletedFuture(
    _awaitCompletedFuture,
    title: 'await một Future đã xong',
    explanation:
        'Hàm async chạy đồng bộ tới await đầu tiên rồi trả Future về cho nơi '
        'gọi. Phần sau await là listener của Future được await; Future đã '
        'xong sẵn thì listener vào hàng đợi microtask ngay lúc await, nên '
        'chạy trước microtask đăng ký sau đó và trước mọi Timer.',
  ),
  asyncGap(
    _asyncGap,
    title: 'Khoảng hở async (async gap)',
    explanation:
        'Từ lúc await một Future chưa xong tới lúc chạy tiếp, code khác '
        '(microtask, Timer, sự kiện UI) được chen vào và đổi trạng thái: ở '
        'đây counter đổi từ 0 thành 1. Vì vậy sau await phải kiểm tra lại '
        'trạng thái (trong Flutter: mounted, đồng hồ còn tồn tại không). Phần '
        'sau await chạy ngay khi Future hoàn thành, tức trong chính lượt '
        'event của Timer đã hoàn thành nó.',
  ),
  nestedMicrotasks(
    _nestedMicrotasks,
    title: 'Microtask sinh thêm microtask',
    explanation:
        'Event loop chỉ lấy sự kiện tiếp theo khi hàng đợi microtask đã rỗng, '
        'kể cả microtask mới sinh ra trong lúc xả. Hệ quả: chuỗi microtask '
        'quá dài hoặc vô hạn sẽ chặn Timer, việc vẽ UI và nhập liệu, làm app '
        'bị treo.',
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
  log('sync: bắt đầu');
  Timer.run(() => log('Timer.run'));
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: kết thúc');
}

void _futureConstructors(LabLog log) {
  log('sync: bắt đầu');
  Future(() => log('Future()'));
  Future.microtask(() => log('Future.microtask'));
  Future.value('xong').then((_) => log('Future.value().then'));
  Future.sync(() => log('Future.sync'));
  log('sync: kết thúc');
}

void _delayedZero(LabLog log) {
  log('sync: bắt đầu');
  Timer.run(() => log('Timer.run #1'));
  Future<void>.delayed(Duration.zero, () => log('Future.delayed(zero)'));
  Timer.run(() => log('Timer.run #2'));
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: kết thúc');
}

void _awaitCompletedFuture(LabLog log) {
  Future<void> worker() async {
    log('worker: trước await');
    await Future<void>.value();
    log('worker: sau await');
  }

  log('sync: gọi worker()');
  worker();
  scheduleMicrotask(() => log('scheduleMicrotask'));
  log('sync: kết thúc');
}

void _asyncGap(LabLog log) {
  var counter = 0;
  Future<void> worker() async {
    log('worker: counter = $counter, await Future.delayed(zero)');
    await Future<void>.delayed(Duration.zero);
    log('worker: sau await, counter = $counter');
  }

  worker();
  log('sync: worker đang chờ, nơi gọi chạy tiếp');
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
    log('microtask 1: đăng ký microtask 2');
    scheduleMicrotask(() => log('microtask 2'));
  });
  log('sync: kết thúc');
}
