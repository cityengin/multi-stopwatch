import 'package:fake_async/fake_async.dart';
import 'package:multi_stopwatch/core/ticker/time_source.dart';

/// [TimeSource] chạy theo thời gian ảo của [FakeAsync]; giờ hệ thống và đồng
/// hồ đơn điệu luôn khớp nhau.
class FakeAsyncTimeSource implements TimeSource {
  FakeAsyncTimeSource(this._async, {DateTime? start})
    : _start = (start ?? DateTime.utc(2026, 1, 1)).toUtc();

  final FakeAsync _async;
  final DateTime _start;

  @override
  DateTime now() => _start.add(_async.elapsed);

  @override
  Duration monotonicNow() => _async.elapsed;
}

/// [TimeSource] mà mỗi lần đọc giờ hệ thống lại tiến thêm [step]; đồng hồ đơn
/// điệu luôn khớp với lần đọc giờ gần nhất.
///
/// Giả lập thời gian trôi giữa hai lần đọc liên tiếp, nên hai đồng hồ tự đọc
/// thời gian riêng sẽ ra hai mốc khác nhau. Dùng để chứng minh một lô thao
/// tác thật sự dùng chung đúng một mốc.
class SteppingTimeSource implements TimeSource {
  SteppingTimeSource({
    this.step = const Duration(milliseconds: 1),
    DateTime? start,
  }) : _start = (start ?? DateTime.utc(2026, 1, 1)).toUtc();

  final Duration step;
  final DateTime _start;
  Duration _elapsed = Duration.zero;

  @override
  DateTime now() {
    _elapsed += step;
    return _start.add(_elapsed);
  }

  @override
  Duration monotonicNow() => _elapsed;
}

/// [TimeSource] tua bằng tay, điều khiển riêng được giờ hệ thống và đồng hồ
/// đơn điệu để giả lập máy ngủ và chỉnh giờ.
class ManualTimeSource implements TimeSource {
  ManualTimeSource({DateTime? wall})
    : _wall = (wall ?? DateTime.utc(2026, 1, 1)).toUtc();

  DateTime _wall;
  Duration _monotonic = Duration.zero;

  @override
  DateTime now() => _wall;

  @override
  Duration monotonicNow() => _monotonic;

  /// Thời gian trôi bình thường: cả hai đồng hồ cùng tiến.
  void advance(Duration duration) {
    _wall = _wall.add(duration);
    _monotonic += duration;
  }

  /// Máy ngủ khi app ở nền: giờ hệ thống tiến, đồng hồ đơn điệu đứng yên.
  void sleep(Duration duration) {
    _wall = _wall.add(duration);
  }

  /// Người dùng hoặc NTP chỉnh giờ hệ thống; đồng hồ đơn điệu không đổi.
  void shiftWallClock(Duration offset) {
    _wall = _wall.add(offset);
  }
}
