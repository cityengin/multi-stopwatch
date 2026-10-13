import 'dart:async';

import '../debug/stream_tracker.dart';

/// Nguồn nhịp dùng chung cho mọi đồng hồ: phát một sự kiện sau mỗi [interval].
///
/// Vì sao một nguồn chung thay vì mỗi đồng hồ một Timer: N đồng hồ chạy song
/// song chỉ tốn một Timer, các ô hiển thị cập nhật cùng nhịp, và chỉ có một chỗ
/// cần dọn dẹp.
///
/// Vì sao chạy lười (lazy): Timer chỉ tồn tại khi có ít nhất một listener; khi
/// listener cuối cùng hủy thì Timer dừng, nên không tốn CPU/pin lúc không ai
/// hiển thị giờ. Cơ chế dựa trên `onListen`/`onCancel` của
/// [StreamController.broadcast]: hai callback này chỉ được gọi khi số listener
/// đi từ 0 lên 1 và từ 1 về 0, đúng hai thời điểm cần bật/tắt Timer.
///
/// Tick chỉ là tín hiệu "đến lúc đọc lại thời gian", KHÔNG dùng để cộng dồn
/// thời gian: Timer có thể bị trễ hoặc bỏ nhịp, nên elapsed phải được tính từ
/// đồng hồ thật tại lúc nhận tick.
class TickSource {
  /// [interval] phải lớn hơn 0. [tracker] (tùy chọn) đếm và ghi log mọi
  /// subscription của [ticks] dưới tên `TickSource.ticks`, để màn Debug thấy
  /// ai đang giữ Timer chạy.
  TickSource({this.interval = defaultInterval, this._tracker})
    : assert(interval > Duration.zero, 'interval phải lớn hơn 0');

  /// ~30 lần/giây: đủ mượt để hiển thị phần trăm giây, nhẹ hơn 60 lần/giây
  /// (16ms) mà mắt khó phân biệt với một con số đang chạy.
  static const defaultInterval = Duration(milliseconds: 33);

  /// Chu kỳ giữa hai tick.
  final Duration interval;

  final StreamTracker? _tracker;

  late final StreamController<int> _controller = StreamController.broadcast(
    onListen: _startTimer,
    onCancel: _stopTimer,
  );

  late final Stream<int> _ticks =
      _tracker?.track('TickSource.ticks', _controller.stream) ??
      _controller.stream;

  Timer? _timer;
  Future<void>? _disposeFuture;

  /// Stream tick (broadcast). Tick đầu tiên đến sau một [interval] kể từ khi
  /// có listener đầu tiên; ai cần giá trị ngay lúc listen thì tự đọc thời gian
  /// hiện tại.
  ///
  /// Giá trị là `Timer.tick`: số chu kỳ đã trôi qua kể từ khi Timer khởi động
  /// (đếm lại từ 1 mỗi lần Timer chạy lại; có thể nhảy cóc khi Timer bị trễ).
  /// Chỉ dùng để đếm/debug, không dùng để tính thời gian.
  Stream<int> get ticks => _ticks;

  /// Timer có đang chạy không; dùng cho test và màn Debug.
  bool get isTicking => _timer != null;

  /// Còn ai đang nghe [ticks] không; dùng cho test và màn Debug.
  bool get hasListener => _controller.hasListener;

  void _startTimer() {
    _timer ??= Timer.periodic(interval, (timer) => _controller.add(timer.tick));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dừng Timer và đóng stream; mọi listener nhận done.
  ///
  /// Idempotent: gọi nhiều lần đều trả về cùng một Future và chỉ dọn dẹp một
  /// lần. Listen sau khi dispose nhận done ngay và không tạo Timer.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _stopTimer();
    await _controller.close();
    _tracker?.recordDispose('TickSource');
  }
}
