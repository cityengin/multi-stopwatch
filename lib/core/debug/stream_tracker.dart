import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import '../ticker/time_source.dart';

/// Loại sự kiện trong log của [StreamTracker].
enum StreamLogKind {
  /// Có subscription mới.
  listen,

  /// Subscription bị hủy từ phía người nghe (kể cả do `cancelOnError`).
  cancel,

  /// Subscription kết thúc vì stream đã đóng (phát done).
  done,

  /// Một thành phần (vd `TickSource`, `StopwatchManager`) đã dispose xong.
  dispose,
}

/// Một dòng trong log của [StreamTracker].
@immutable
class StreamLogEvent {
  const StreamLogEvent({
    required this.kind,
    required this.source,
    required this.activeCount,
    required this.at,
  });

  final StreamLogKind kind;

  /// Tên luồng hoặc thành phần, vd `elapsedStream:<taskId>`.
  final String source;

  /// Tổng số subscription còn hoạt động ngay sau sự kiện này.
  final int activeCount;

  /// Thời điểm ghi (UTC).
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is StreamLogEvent &&
      other.kind == kind &&
      other.source == source &&
      other.activeCount == activeCount &&
      other.at == at;

  @override
  int get hashCode => Object.hash(kind, source, activeCount, at);

  @override
  String toString() => '${kind.name} $source (active: $activeCount)';
}

/// Theo dõi subscription của các stream để chứng minh luồng được hủy an toàn:
/// đếm số subscription đang hoạt động và phát log listen/cancel/done/dispose.
/// UI dùng cho màn Debug.
///
/// Vì sao bọc stream bằng [track] thay vì để mỗi nơi tự báo: việc đếm nằm ở
/// đúng một chỗ, ngay lúc listen và lúc subscription kết thúc (cancel hoặc
/// done), nên không thể quên báo; nơi dùng chỉ cần bọc stream của mình.
///
/// Vì sao [events] là broadcast bất đồng bộ: sự kiện được ghi ngay trong
/// `onListen`/`onCancel` của các luồng khác. Phát đồng bộ thì listener của màn
/// Debug sẽ chạy lồng bên trong các callback đó; nếu nó lại listen/cancel một
/// luồng được theo dõi thì thành phát sự kiện lồng nhau.
class StreamTracker {
  /// [historyLimit] là số sự kiện gần nhất được giữ lại trong [history].
  StreamTracker({TimeSource? timeSource, this.historyLimit = 200})
    : assert(historyLimit >= 0, 'historyLimit không âm'),
      _time = timeSource ?? SystemTimeSource();

  final int historyLimit;
  final TimeSource _time;
  final Map<String, int> _active = {};
  final Queue<StreamLogEvent> _history = Queue();
  final StreamController<StreamLogEvent> _events = StreamController.broadcast();
  int _activeCount = 0;
  Future<void>? _disposeFuture;

  /// Tổng số subscription đang hoạt động trên mọi luồng được theo dõi.
  int get activeCount => _activeCount;

  /// Số subscription đang hoạt động theo từng luồng; luồng về 0 thì không còn
  /// trong map.
  Map<String, int> get activeBySource => Map.unmodifiable(_active);

  /// Log sự kiện mới (broadcast).
  Stream<StreamLogEvent> get events => _events.stream;

  /// Các sự kiện gần nhất, cũ trước mới sau.
  ///
  /// Vì sao giữ lại: màn Debug mở sau vẫn thấy được những gì đã xảy ra trước
  /// đó, không chỉ sự kiện mới.
  List<StreamLogEvent> get history => List.unmodifiable(_history);

  /// Bọc [stream] để mỗi subscription của nó được đếm và ghi log dưới tên
  /// [source].
  ///
  /// Dữ liệu, lỗi, pause/resume và cancel được chuyển nguyên vẹn; stream trả
  /// về giữ nguyên tính broadcast của [stream].
  ///
  /// Vì sao `onCancel` không trả Future khi nguồn đã done: SDK hủy subscription
  /// trước rồi mới giao done, và nếu `onCancel` trả về một Future thì done phải
  /// chờ Future đó. Nguồn đã kết thúc thì không còn gì để chờ, trả Future chỉ
  /// làm done đến trễ không cần thiết.
  Stream<T> track<T>(String source, Stream<T> stream) =>
      Stream<T>.multi((controller) {
        _record(StreamLogKind.listen, source, delta: 1);
        var active = true;
        void release(StreamLogKind kind) {
          if (!active) return;
          active = false;
          _record(kind, source, delta: -1);
        }

        final subscription = stream.listen(
          controller.addSync,
          onError: controller.addErrorSync,
          onDone: () {
            release(StreamLogKind.done);
            controller.closeSync();
          },
        );
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume
          ..onCancel = () {
            if (!active) return null;
            release(StreamLogKind.cancel);
            return subscription.cancel();
          };
      }, isBroadcast: stream.isBroadcast);

  /// Ghi sự kiện [StreamLogKind.dispose] của thành phần [source].
  void recordDispose(String source) => _record(StreamLogKind.dispose, source);

  /// Đóng [events]. Idempotent; sau đó vẫn đếm đúng nhưng không phát log nữa.
  Future<void> dispose() => _disposeFuture ??= _events.close();

  void _record(StreamLogKind kind, String source, {int delta = 0}) {
    if (delta != 0) {
      final count = (_active[source] ?? 0) + delta;
      if (count == 0) {
        _active.remove(source);
      } else {
        _active[source] = count;
      }
      _activeCount += delta;
    }
    if (_disposeFuture != null) return;
    final event = StreamLogEvent(
      kind: kind,
      source: source,
      activeCount: _activeCount,
      at: _time.now(),
    );
    _history.addLast(event);
    while (_history.length > historyLimit) {
      _history.removeFirst();
    }
    _events.add(event);
  }
}
