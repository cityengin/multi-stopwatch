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
