import '../models/task_status.dart';

/// Lỗi nghiệp vụ của `StopwatchService` mà UI nên bắt và hiển thị.
///
/// Vì sao là `sealed`: UI có thể `switch` trên lỗi và compiler kiểm tra đủ
/// mọi trường hợp. Vì sao là Exception (không phải Error): đây là tình huống
/// dự kiến được (vd bấm pause hai lần liên tiếp), không phải lỗi lập trình.
sealed class StopwatchException implements Exception {
  const StopwatchException(this.message);

  final String message;
}

/// Không có đồng hồ nào mang [taskId], ví dụ đồng hồ vừa bị xóa ở chỗ khác.
final class TaskNotFoundException extends StopwatchException {
  TaskNotFoundException(this.taskId)
    : super('Không tìm thấy đồng hồ "$taskId".');

  final String taskId;

  @override
  String toString() => 'TaskNotFoundException: $message';
}

/// Thao tác [action] không hợp lệ khi đồng hồ đang ở trạng thái [status],
/// ví dụ pause một đồng hồ đang idle.
final class InvalidTransitionException extends StopwatchException {
  InvalidTransitionException({
    required this.taskId,
    required this.action,
    required this.status,
  }) : super('Không thể $action đồng hồ "$taskId" khi đang ${status.name}.');

  final String taskId;

  /// Tên thao tác bị từ chối: "start", "pause", "resume" hoặc "lap".
  final String action;

  final TaskStatus status;

  @override
  String toString() => 'InvalidTransitionException: $message';
}
