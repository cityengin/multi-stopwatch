import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';

/// [TaskRepository] cho test: bọc [InMemoryTaskRepository], có thể làm ghi
/// chậm ([writeDelay]) hoặc ghi lỗi ([failWrites]).
class FlakyTaskRepository implements TaskRepository {
  FlakyTaskRepository([InMemoryTaskRepository? inner])
    : _inner = inner ?? InMemoryTaskRepository();

  final InMemoryTaskRepository _inner;
  bool failWrites = false;
  Duration writeDelay = Duration.zero;

  @override
  Future<List<StopwatchTask>> loadAll() => _inner.loadAll();

  @override
  Future<void> upsert(StopwatchTask task) async {
    await _beforeWrite();
    await _inner.upsert(task);
  }

  @override
  Future<void> delete(String taskId) async {
    await _beforeWrite();
    await _inner.delete(taskId);
  }

  Future<void> _beforeWrite() async {
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    if (failWrites) throw StorageException('Lỗi ghi giả lập');
  }
}
