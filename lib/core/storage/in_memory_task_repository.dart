import 'dart:convert';

import '../models/stopwatch_task.dart';
import 'task_repository.dart';

/// [TaskRepository] giả trong bộ nhớ: mất hết dữ liệu khi app tắt, dùng tạm
/// trước khi có lưu trữ thật và dùng trong test.
///
/// Vì sao lưu chuỗi JSON thay vì giữ thẳng object: dữ liệu đi qua đúng đường
/// `toJson`/`fromJson` như lưu trữ thật, nên lỗi serialize lộ ra ngay từ bây
/// giờ; và mỗi lần [loadAll] trả về object mới, không chia sẻ gì với service.
class InMemoryTaskRepository implements TaskRepository {
  /// [initial] là dữ liệu có sẵn, vd để giả lập lần mở app trước đã lưu.
  InMemoryTaskRepository([Iterable<StopwatchTask> initial = const []]) {
    for (final task in initial) {
      _rows[task.id] = jsonEncode(task.toJson());
    }
  }

  /// Map giữ thứ tự chèn và ghi đè không đổi vị trí, đúng thứ tự mà
  /// [TaskRepository] yêu cầu.
  final Map<String, String> _rows = {};

  @override
  Future<List<StopwatchTask>> loadAll() async {
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
    _rows[task.id] = jsonEncode(task.toJson());
  }

  @override
  Future<void> delete(String taskId) async {
    _rows.remove(taskId);
  }
}
