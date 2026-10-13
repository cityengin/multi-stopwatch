/// Throttle và debounce viết bằng [StreamTransformer] thuần Dart (không dùng
/// rxdart).
///
/// Khác biệt, ví dụ với duration = 300ms (mỗi ô là 100ms):
/// ```text
/// thời gian:            0  1  2  3  4  5  6  7  8  9  10 11
/// nguồn:                a  b  c              d  e
/// throttle:             a                    d
/// throttle (trailing):  a        c           d        e
/// debounce:                            c                 e
/// ```
///
/// - Throttle phát ngay sự kiện đầu rồi "đóng cửa" trong duration; sự kiện đến
///   lúc cửa đóng bị bỏ (hoặc, với `trailing`, giữ lại cái cuối để phát khi cửa
///   mở). Nguồn phát liên tục thì đầu ra vẫn đều đặn, tối đa một sự kiện mỗi
///   duration.
///   Dùng khi: cần giảm tần suất một stream phát liên tục mà vẫn thấy cập nhật
///   đều, vd `elapsedStream` 30 lần/giây nhưng ô trong danh sách chỉ cần 1
///   lần/giây (bật `trailing` để không mất giá trị cuối khi pause); hoặc chặn
///   bấm nút liên tục, chỉ lấy cú bấm đầu.
/// - Debounce đặt lại thời gian chờ sau mỗi sự kiện, và chỉ phát sự kiện cuối
///   khi nguồn đã im lặng đủ duration. Nguồn phát liên tục thì đầu ra im lặng
///   mãi.
///   Dùng khi: chờ người dùng "làm xong", vd gõ xong tên đồng hồ mới gọi
///   `renameTask` (không lưu theo từng phím), ô tìm kiếm, kéo thanh trượt.
///   Không dùng cho stream tick vì sẽ không bao giờ phát.
///
/// Hành vi chung của cả hai:
/// - Lỗi được chuyển đi ngay, không ảnh hưởng sự kiện đang chờ hay cửa sổ
///   throttle.
/// - Khi nguồn done: sự kiện đang chờ (debounce, throttle `trailing`) được phát
///   ngay rồi mới done, nên không mất giá trị cuối.
/// - Cancel: hủy Timer và subscription nguồn, không Timer nào còn sống.
/// - Pause (stream single-subscription): pause lan ngược về nguồn. Timer đang
///   chờ vẫn chạy, giá trị nó phát được giữ lại tới khi resume.
/// - Broadcast: nguồn broadcast thì đầu ra cũng broadcast. Nguồn chỉ được nghe
///   khi có ít nhất một listener, mọi listener dùng chung một trạng thái, và
///   hết listener rồi listen lại thì bắt đầu lại từ đầu. Pause của một listener
///   chỉ ảnh hưởng listener đó (stream broadcast không pause được nguồn).
library;

import 'dart:async';

/// Throttle: phát ngay sự kiện đầu, rồi bỏ qua các sự kiện trong [duration]
/// kế tiếp. Xem so sánh với debounce ở đầu file.
class ThrottleTransformer<T> extends StreamTransformerBase<T, T> {
  /// [trailing] = true: sự kiện cuối cùng bị chặn trong cửa sổ được phát khi
  /// cửa sổ kết thúc (và mở một cửa sổ mới), nên giá trị mới nhất luôn đến
  /// được đầu ra.
  ThrottleTransformer(this.duration, {this.trailing = false})
    : assert(duration > Duration.zero, 'duration phải lớn hơn 0');

  final Duration duration;
  final bool trailing;

  @override
  Stream<T> bind(Stream<T> stream) =>
      _bindGate(stream, () => _ThrottleGate<T>(duration, trailing));
}

/// Debounce: chỉ phát sự kiện cuối cùng sau khi nguồn im lặng đủ [duration].
/// Xem so sánh với throttle ở đầu file.
class DebounceTransformer<T> extends StreamTransformerBase<T, T> {
  DebounceTransformer(this.duration)
    : assert(duration > Duration.zero, 'duration phải lớn hơn 0');

  final Duration duration;

  @override
  Stream<T> bind(Stream<T> stream) =>
      _bindGate(stream, () => _DebounceGate<T>(duration));
}

/// Cách viết gọn: `stream.throttled(...)`, `stream.debounced(...)`.
///
/// Vì sao tên có đuôi "-ed": tránh trùng với `throttle`/`debounce` của rxdart
/// nếu sau này phía UI có dùng.
extension RateLimitStreamExtension<T> on Stream<T> {
  Stream<T> throttled(Duration duration, {bool trailing = false}) =>
      transform(ThrottleTransformer<T>(duration, trailing: trailing));

  Stream<T> debounced(Duration duration) =>
      transform(DebounceTransformer<T>(duration));
}

/// Phần riêng của từng transformer: quyết định khi nào phát sự kiện.
abstract interface class _Gate<T> {
  void onData(T event, EventSink<T> sink);

  /// Phát nốt sự kiện đang chờ (nếu có) trước khi đầu ra done.
  void onDone(EventSink<T> sink);

  /// Hủy mọi Timer và quên sự kiện đang chờ.
  void dispose();
}

/// Phần chung của mọi transformer: quản lý subscription nguồn theo vòng đời
/// của đầu ra (listen, pause/resume, cancel, done, lỗi).
///
/// Vì sao tạo [_Gate] mới mỗi lần listen: một transformer có thể `bind` nhiều
/// stream, và đầu ra broadcast có thể được listen lại; trạng thái cũ (Timer,
/// sự kiện đang chờ) không được lẫn sang lần sau.
///
/// Vì sao controller `sync: true`: sự kiện đã đến bất đồng bộ từ nguồn hoặc
/// từ Timer, chuyển tiếp đồng bộ tránh trễ thêm một microtask mỗi lần.
Stream<T> _bindGate<T>(Stream<T> source, _Gate<T> Function() createGate) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  _Gate<T>? gate;

  void listen() {
    final current = gate = createGate();
    subscription = source.listen(
      (event) => current.onData(event, controller),
      onError: controller.addError,
      onDone: () {
        current.onDone(controller);
        current.dispose();
        gate = null;
        subscription = null;
        controller.close();
      },
    );
  }

  Future<void> cancel() {
    gate?.dispose();
    gate = null;
    final active = subscription;
    subscription = null;
    return active?.cancel() ?? Future.value();
  }

  if (source.isBroadcast) {
    controller = StreamController<T>.broadcast(
      onListen: listen,
      onCancel: cancel,
      sync: true,
    );
  } else {
    controller = StreamController<T>(
      onListen: listen,
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: cancel,
      sync: true,
    );
  }
  return controller.stream;
}

class _ThrottleGate<T> implements _Gate<T> {
  _ThrottleGate(this._duration, this._trailing);

  final Duration _duration;
  final bool _trailing;
  Timer? _window;
  bool _hasTrailing = false;
  T? _trailingEvent;

  @override
  void onData(T event, EventSink<T> sink) {
    if (_window == null) {
      sink.add(event);
      _openWindow(sink);
    } else if (_trailing) {
      _hasTrailing = true;
      _trailingEvent = event;
    }
  }

  void _openWindow(EventSink<T> sink) {
    _window = Timer(_duration, () {
      _window = null;
      if (_takeTrailing(sink)) _openWindow(sink);
    });
  }

  /// Phát sự kiện trailing đang giữ (nếu có); trả về true nếu đã phát.
  bool _takeTrailing(EventSink<T> sink) {
    if (!_hasTrailing) return false;
    final event = _trailingEvent as T;
    _hasTrailing = false;
    _trailingEvent = null;
    sink.add(event);
    return true;
  }

  @override
  void onDone(EventSink<T> sink) {
    _window?.cancel();
    _window = null;
    _takeTrailing(sink);
  }

  @override
  void dispose() {
    _window?.cancel();
    _window = null;
    _hasTrailing = false;
    _trailingEvent = null;
  }
}

class _DebounceGate<T> implements _Gate<T> {
  _DebounceGate(this._duration);

  final Duration _duration;
  Timer? _timer;
  bool _hasPending = false;
  T? _pending;

  @override
  void onData(T event, EventSink<T> sink) {
    _timer?.cancel();
    _hasPending = true;
    _pending = event;
    _timer = Timer(_duration, () => _flush(sink));
  }

  void _flush(EventSink<T> sink) {
    _timer = null;
    if (!_hasPending) return;
    final event = _pending as T;
    _hasPending = false;
    _pending = null;
    sink.add(event);
  }

  @override
  void onDone(EventSink<T> sink) {
    _timer?.cancel();
    _flush(sink);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _hasPending = false;
    _pending = null;
  }
}
