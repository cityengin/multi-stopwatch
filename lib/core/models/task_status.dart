/// Trạng thái vòng đời của một đồng hồ.
///
/// Vì sao dùng enum thay cho nhiều cờ bool (isRunning, isPaused...): tại một
/// thời điểm chỉ có đúng một trạng thái hợp lệ, và `switch` trên enum được
/// compiler kiểm tra đủ trường hợp.
enum TaskStatus {
  /// Chưa chạy lần nào hoặc vừa reset: elapsed = 0, không có lap.
  idle,

  /// Đang chạy: elapsed tăng theo thời gian thực.
  running,

  /// Tạm dừng: giữ nguyên elapsed và các lap.
  paused,
}
