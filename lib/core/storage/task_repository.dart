import '../models/stopwatch_task.dart';

/// Nơi lưu trữ các đồng hồ (database giả lập, shared_preferences...).
///
/// Vì sao tách thành interface: service không cần biết dữ liệu nằm ở đâu.
/// Test dùng bản in-memory, app dùng shared_preferences, và có thể thêm bản
/// giả lập độ trễ/lỗi như gọi API thật mà không phải sửa service.
///
/// Vì sao mọi method trả Future: lưu trữ thật luôn là I/O bất đồng bộ; bản
/// in-memory cũng giữ cùng chữ ký để có thể thay thế cho nhau.
///
/// Mọi lỗi lưu/đọc được báo bằng [StorageException].
abstract interface class TaskRepository {
  /// Đọc toàn bộ đồng hồ theo thứ tự đã lưu; trả list rỗng nếu chưa có gì.
  ///
  /// Dữ liệu hỏng (sai định dạng) cũng báo bằng [StorageException].
  Future<List<StopwatchTask>> loadAll();

  /// Thêm mới, hoặc ghi đè nếu đã có [StopwatchTask.id] này.
  ///
  /// Đồng hồ đã có giữ nguyên vị trí; đồng hồ mới được thêm vào cuối.
  /// Future hoàn thành khi dữ liệu đã được ghi xong.
  Future<void> upsert(StopwatchTask task);

  /// Xóa theo id. Id không tồn tại thì không làm gì và không báo lỗi.
  ///
  /// Vì sao idempotent: thử lại (retry) sau lỗi mạng/IO luôn an toàn.
  Future<void> delete(String taskId);
}

/// Lỗi đọc/ghi dữ liệu.
///
/// Vì sao là Exception (không phải Error): lỗi I/O là tình huống dự kiến được,
/// tầng trên cần bắt để báo người dùng hoặc thử lại.
class StorageException implements Exception {
  StorageException(this.message, {this.cause});

  final String message;

  /// Lỗi gốc (vd [FormatException] khi dữ liệu hỏng), giữ lại để debug.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'StorageException: $message'
      : 'StorageException: $message (cause: $cause)';
}
