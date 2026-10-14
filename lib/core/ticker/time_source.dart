import 'package:meta/meta.dart';

/// Nguồn thời gian được inject vào `ElapsedTracker`.
///
/// Vì sao là interface: test thay bằng đồng hồ giả để tua thời gian tùy ý
/// (kể cả giả lập máy ngủ hay người dùng chỉnh giờ) mà không phải chờ thật.
///
/// Vì sao cần hai loại thời gian: mỗi loại chỉ đúng trong một hoàn cảnh, nên
/// phải kết hợp cả hai (xem `ElapsedTracker`).
abstract interface class TimeSource {
  /// Giờ hệ thống (UTC).
  ///
  /// Còn nguyên sau khi tắt/mở app nên dùng để lưu mốc, nhưng có thể bị người
  /// dùng hoặc NTP chỉnh tiến/lùi bất kỳ lúc nào.
  DateTime now();

  /// Thời gian đơn điệu, tính từ một mốc tùy ý.
  ///
  /// Không bao giờ lùi và không bị ảnh hưởng khi chỉnh giờ, nhưng mốc mất khi
  /// tiến trình kết thúc và có thể đứng yên trong lúc máy ngủ.
  Duration monotonicNow();
}

/// [TimeSource] thật: giờ hệ thống và một [Stopwatch] chạy từ lúc tạo.
///
/// Nên dùng chung một instance cho mọi đồng hồ: một Stopwatch là đủ, không
/// cần mỗi đồng hồ một cái.
class SystemTimeSource implements TimeSource {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  DateTime now() => DateTime.now().toUtc();

  @override
  Duration monotonicNow() => _stopwatch.elapsed;
}

/// Một lần đọc cả hai loại thời gian của [TimeSource].
///
/// Vì sao cần: thao tác hàng loạt (vd chạy tất cả đồng hồ) phải dùng chung
/// đúng một mốc cho cả lô. Nếu mỗi đồng hồ tự đọc thời gian thì các mốc lệch
/// nhau một chút theo thứ tự xử lý.
@immutable
class TimeReading {
  const TimeReading({required this.wall, required this.monotonic});

  /// Giờ hệ thống (UTC) lúc đọc.
  final DateTime wall;

  /// Đồng hồ đơn điệu lúc đọc.
  final Duration monotonic;
}

/// Đọc một [TimeReading] từ [TimeSource].
///
/// Vì sao là extension chứ không thêm method vào [TimeSource]: các nguồn thời
/// gian đã có (kể cả bản giả trong test) không phải sửa gì.
extension TimeSourceReading on TimeSource {
  /// Đọc giờ hệ thống trước rồi tới đồng hồ đơn điệu, cùng thứ tự với
  /// `ElapsedTracker`.
  TimeReading read() => TimeReading(wall: now(), monotonic: monotonicNow());
}
