import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';

/// [TaskRepository] cho test: bọc một repository khác và ghi lại mọi lần ghi,
/// để kiểm tra service ghi bao nhiêu lần và ghi những gì.
class CountingTaskRepository implements TaskRepository {
  CountingTaskRepository([TaskRepository? inner])
    : _inner = inner ?? InMemoryTaskRepository();

  final TaskRepository _inner;

  /// Mỗi lần ghi một dòng, vd `upsertAll(2)` hay `delete`.
  final writes = <String>[];

  @override
  Future<List<StopwatchTask>> loadAll() => _inner.loadAll();

  @override
  Future<void> upsert(StopwatchTask task) {
    writes.add('upsert');
    return _inner.upsert(task);
  }

  @override
  Future<void> delete(String taskId) {
    writes.add('delete');
    return _inner.delete(taskId);
  }

  @override
  Future<void> upsertAll(Iterable<StopwatchTask> tasks) {
    final batch = tasks.toList();
    writes.add('upsertAll(${batch.length})');
    return _inner.upsertAll(batch);
  }

  @override
  Future<void> deleteAll(Iterable<String> taskIds) {
    final batch = taskIds.toList();
    writes.add('deleteAll(${batch.length})');
    return _inner.deleteAll(batch);
  }
}
