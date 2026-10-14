import '../models/stopwatch_task.dart';
import 'task_repository.dart';

/// Bọc một [TaskRepository] khác và tự thử lại khi gặp [StorageException].
///
/// Vì sao thử lại là an toàn: mọi thao tác của [TaskRepository] đều idempotent
/// (`loadAll` chỉ đọc, `upsert` ghi đè theo id, `delete` id không tồn tại cũng
/// không lỗi). Làm lại một thao tác mà lần trước đã "lỡ" thành công cũng không
/// làm sai dữ liệu.
///
/// Vì sao chờ tăng dần (exponential backoff: [initialDelay], gấp đôi, gấp
/// bốn...): lỗi tạm thời như mạng chập chờn hay server quá tải cần thời gian
/// hồi phục. Thử lại ngay lập tức dễ thất bại tiếp và còn làm server nặng thêm.
///
/// Vì sao chỉ thử lại [StorageException]: đó là lỗi I/O dự kiến được. Lỗi khác
/// (vd lỗi lập trình) thử lại bao nhiêu lần cũng vậy, nên được ném ra ngay.
///
/// Vì sao là lớp bọc (decorator) chứ không viết retry trong service: service
/// không cần biết có retry hay không; ghép `RetryingTaskRepository(api)` khi
/// cần, bỏ đi khi lưu trên máy (nơi lỗi thường không tự hết).
class RetryingTaskRepository implements TaskRepository {
  /// [maxAttempts] tính cả lần gọi đầu, phải từ 1 trở lên. [onRetry] được gọi
  /// trước mỗi lần thử lại, vd để màn Debug hiển thị.
  RetryingTaskRepository(
    this._inner, {
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.onRetry,
  }) : assert(maxAttempts >= 1, 'maxAttempts từ 1 trở lên'),
       assert(!initialDelay.isNegative, 'initialDelay không âm');

  final TaskRepository _inner;
  final int maxAttempts;
  final Duration initialDelay;

  /// Nhận số thứ tự lần thử sắp tới (bắt đầu từ 2) và lỗi của lần vừa hỏng.
  final void Function(int nextAttempt, StorageException error)? onRetry;

  @override
  Future<List<StopwatchTask>> loadAll() => _retry(_inner.loadAll);

  @override
  Future<void> upsert(StopwatchTask task) => _retry(() => _inner.upsert(task));

  @override
  Future<void> delete(String taskId) => _retry(() => _inner.delete(taskId));

  /// Vì sao chép sang list trước: [Iterable] có thể được tính lười hoặc chỉ
  /// duyệt được một lần, mà mỗi lần thử lại phải gửi đúng cùng một lô.
  @override
  Future<void> upsertAll(Iterable<StopwatchTask> tasks) {
    final batch = tasks.toList();
    return _retry(() => _inner.upsertAll(batch));
  }

  @override
  Future<void> deleteAll(Iterable<String> taskIds) {
    final batch = taskIds.toList();
    return _retry(() => _inner.deleteAll(batch));
  }

  Future<T> _retry<T>(Future<T> Function() action) async {
    var delay = initialDelay;
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } on StorageException catch (error) {
        if (attempt >= maxAttempts) rethrow;
        onRetry?.call(attempt + 1, error);
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
  }
}
