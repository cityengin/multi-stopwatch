import 'dart:convert';
import 'dart:math';

import '../models/stopwatch_task.dart';
import 'task_repository.dart';

/// [TaskRepository] giả lập một API trên server, dữ liệu nằm trong bộ nhớ và
/// mất khi app tắt.
///
/// Mỗi lần gọi đều chờ [latency] bằng `Future.delayed` như một request mạng,
/// rồi có thể thất bại theo [failureRate] hoặc [failNext]. Nhờ vậy service và
/// UI được thử với độ trễ và lỗi thật, kể cả cơ chế thử lại
/// (`RetryingTaskRepository`).
///
/// Vì sao lưu chuỗi JSON thay vì giữ thẳng object: dữ liệu đi qua đúng đường
/// `toJson`/`fromJson` như khi gửi lên server, nên lỗi serialize lộ ra ngay;
/// và mỗi lần [loadAll] trả về object mới, không chia sẻ gì với service.
class InMemoryTaskRepository implements TaskRepository {
  /// [initial] là dữ liệu có sẵn trên "server". [random] để test truyền seed
  /// cố định, cho kết quả [failureRate] lặp lại được.
  InMemoryTaskRepository({
    Iterable<StopwatchTask> initial = const [],
    this.latency = Duration.zero,
    this.failureRate = 0,
    Random? random,
  }) : assert(failureRate >= 0 && failureRate <= 1, 'failureRate từ 0 tới 1'),
       _random = random ?? Random() {
    for (final task in initial) {
      _rows[task.id] = jsonEncode(task.toJson());
    }
  }

  /// Độ trễ của mỗi lần gọi. Đổi được lúc đang chạy để giả lập mạng chậm đi
  /// hay nhanh lên.
  Duration latency;

  /// Xác suất (0 tới 1) mỗi lần gọi thất bại với [StorageException]. Đổi được
  /// lúc đang chạy; 1 nghĩa là "mất mạng" hoàn toàn.
  double failureRate;

  final Random _random;
  int _forcedFailures = 0;

  /// Map giữ thứ tự chèn và ghi đè không đổi vị trí, đúng thứ tự mà
  /// [TaskRepository] yêu cầu.
  final Map<String, String> _rows = {};

  /// Buộc [count] lần gọi kế tiếp thất bại, bất kể [failureRate].
  ///
  /// Vì sao có thêm cách này: test retry cần biết chắc lần nào lỗi, còn
  /// [failureRate] ngẫu nhiên hợp để demo hơn.
  void failNext([int count = 1]) {
    assert(count >= 0, 'count không âm');
    _forcedFailures += count;
  }

  @override
  Future<List<StopwatchTask>> loadAll() async {
    await _simulateRequest('đọc danh sách đồng hồ');
    try {
      return [
        for (final raw in _rows.values)
          StopwatchTask.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      ];
    } on FormatException catch (error) {
      throw StorageException('Dữ liệu đồng hồ bị hỏng.', cause: error);
    }
  }

  @override
  Future<void> upsert(StopwatchTask task) async {
    await _simulateRequest('lưu đồng hồ "${task.id}"');
    _rows[task.id] = jsonEncode(task.toJson());
  }

  @override
  Future<void> delete(String taskId) async {
    await _simulateRequest('xóa đồng hồ "$taskId"');
    _rows.remove(taskId);
  }

  /// Chờ như một request mạng rồi quyết định thành công hay lỗi. Lỗi xảy ra
  /// sau độ trễ, như request bị timeout, và không làm thay đổi dữ liệu.
  Future<void> _simulateRequest(String operation) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_forcedFailures > 0) {
      _forcedFailures--;
      throw StorageException('Lỗi giả lập khi $operation.');
    }
    if (failureRate > 0 && _random.nextDouble() < failureRate) {
      throw StorageException('Lỗi mạng giả lập khi $operation.');
    }
  }
}
