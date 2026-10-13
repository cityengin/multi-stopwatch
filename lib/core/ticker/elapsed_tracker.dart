import 'time_source.dart';

/// Đo elapsed chính xác cho một đồng hồ theo công thức
/// `elapsed = accumulated + (bây giờ - mốc bắt đầu đoạn đang chạy)`.
///
/// Vì sao KHÔNG cộng dồn `+interval` mỗi tick: sai số của cách đó chỉ tích
/// lũy, không bao giờ tự bù lại.
/// - Callback của Timer chỉ chạy khi event loop rảnh. Khi bị chặn lâu hơn một
///   chu kỳ (build frame nặng, GC, I/O đồng bộ), Dart bỏ qua các nhịp bị lỡ và
///   chỉ gọi callback một lần (`Timer.tick` nhảy cóc). Mỗi lần giật như vậy,
///   cách cộng dồn mất trắng vài chục đến vài trăm ms.
/// - App xuống nền thì Timer ngừng hẳn, toàn bộ thời gian ở nền bị mất.
/// - Thời gian bị đếm theo số lần callback chứ không theo đồng hồ thật, nên
///   chạy 1 giờ với các lần giật lặt vặt có thể lệch tới hàng phút.
///
/// Với cách tính theo mốc, tick chỉ là lúc "đọc lại": tick đến trễ thì đọc
/// trễ, nhưng giá trị đọc được vẫn đúng và sai số không cộng dồn.
///
/// Vì sao dùng hai nguồn thời gian của [TimeSource]:
/// - Trong phiên dùng đồng hồ đơn điệu (Stopwatch), nên elapsed không nhảy khi
///   người dùng hoặc NTP chỉnh giờ hệ thống.
/// - Mốc giờ hệ thống [runningSince] được lưu lại để khôi phục sau khi khởi
///   động lại (Stopwatch mất theo tiến trình), và để bù thời gian máy ngủ khi
///   app ở nền (đồng hồ đơn điệu có thể đứng yên lúc máy ngủ).
///
/// Mỗi lần đọc, hai nguồn được đối chiếu. Nếu chênh lệch vượt [syncThreshold]:
/// - Giờ hệ thống đi trước: coi như app vừa ở nền lúc máy ngủ, cộng phần chênh
///   vào. Hạn chế đã biết: không phân biệt được với việc người dùng chỉnh giờ
///   tiến.
/// - Giờ hệ thống đi sau (bị chỉnh lùi): giữ nguyên elapsed, chỉ dời
///   [runningSince] để lần khôi phục sau vẫn ra đúng.
///
/// Nhờ vậy elapsed trong một phiên không bao giờ giảm.
class ElapsedTracker {
  /// Truyền [accumulated] và [runningSince] đã lưu để khôi phục một đồng hồ;
  /// [runningSince] khác null nghĩa là đồng hồ đang chạy. Thời gian app bị tắt
  /// (từ [runningSince] đến giờ hệ thống hiện tại) được tính vào elapsed.
  ElapsedTracker({
    TimeSource? timeSource,
    Duration accumulated = Duration.zero,
    DateTime? runningSince,
    this.syncThreshold = defaultSyncThreshold,
  }) : assert(!accumulated.isNegative, 'accumulated không âm'),
       assert(!syncThreshold.isNegative, 'syncThreshold không âm'),
       _time = timeSource ?? SystemTimeSource(),
       _accumulated = accumulated {
    if (runningSince != null) {
      final wallNow = _time.now();
      final offline = wallNow.difference(runningSince);
      final gap = offline.isNegative ? Duration.zero : offline;
      _runningSince = wallNow.subtract(gap);
      _monotonicAnchor = _time.monotonicNow() - gap;
    }
  }

  /// Vì sao 1 giây: đủ lớn để bỏ qua nhiễu và độ lệch tự nhiên giữa hai đồng
  /// hồ, đủ nhỏ để bắt được mọi lần app ở nền lúc máy ngủ.
  static const defaultSyncThreshold = Duration(seconds: 1);

  /// Chênh lệch tối thiểu giữa hai nguồn thời gian thì mới điều chỉnh.
  ///
  /// Vì sao cần ngưỡng: hai nguồn được đọc ở hai thời điểm sát nhau nên luôn
  /// lệch vài µs. Nếu điều chỉnh cả chênh lệch nhỏ, mỗi lần đọc lại cộng thêm
  /// một chút nhiễu và elapsed sẽ trôi dần.
  final Duration syncThreshold;

  final TimeSource _time;
  Duration _accumulated;
  DateTime? _runningSince;
  Duration? _monotonicAnchor;

  bool get isRunning => _monotonicAnchor != null;

  /// Tổng các đoạn chạy đã kết thúc.
  Duration get accumulated => _accumulated;

  /// Mốc giờ hệ thống (UTC) của đoạn đang chạy, dùng để lưu trữ; null khi
  /// không chạy. Có thể bị dời khi phát hiện giờ hệ thống bị chỉnh lùi.
  DateTime? get runningSince {
    _syncSegment();
    return _runningSince;
  }

  /// Elapsed tại lúc đọc.
  Duration get elapsed {
    final segment = _syncSegment();
    return segment == null ? _accumulated : _accumulated + segment;
  }

  /// Bắt đầu một đoạn chạy mới; ném [StateError] nếu đang chạy.
  void start() {
    if (isRunning) throw StateError('ElapsedTracker đang chạy.');
    _runningSince = _time.now();
    _monotonicAnchor = _time.monotonicNow();
  }

  /// Kết thúc đoạn đang chạy, gộp vào [accumulated] và trả về elapsed; ném
  /// [StateError] nếu không chạy.
  Duration stop() {
    if (!isRunning) throw StateError('ElapsedTracker không chạy.');
    _accumulated = elapsed;
    _runningSince = null;
    _monotonicAnchor = null;
    return _accumulated;
  }

  /// Về 0 và dừng, từ bất kỳ trạng thái nào.
  void reset() {
    _accumulated = Duration.zero;
    _runningSince = null;
    _monotonicAnchor = null;
  }

  /// Đối chiếu hai nguồn thời gian và trả về độ dài đoạn đang chạy; null khi
  /// không chạy.
  Duration? _syncSegment() {
    final anchor = _monotonicAnchor;
    final since = _runningSince;
    if (anchor == null || since == null) return null;
    final wallNow = _time.now();
    final monotonicSegment = _time.monotonicNow() - anchor;
    final drift = wallNow.difference(since) - monotonicSegment;
    if (drift > syncThreshold) {
      _monotonicAnchor = anchor - drift;
      return monotonicSegment + drift;
    }
    if (drift < -syncThreshold) {
      _runningSince = wallNow.subtract(monotonicSegment);
    }
    return monotonicSegment;
  }
}
