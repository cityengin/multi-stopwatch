import 'dart:async';

import 'package:multi_stopwatch/core/debug/stream_tracker.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';

/// Fake implementation của [StopwatchService] phục vụ kiểm thử UI mà không cần
/// dùng package mock ngoài (tuân thủ quy tắc 5).
class FakeStopwatchService implements StopwatchService {
  FakeStopwatchService({
    List<TaskSnapshot> initialTasks = const [],
    this.tracker,
  }) : _tasks = List.of(initialTasks);

  final List<TaskSnapshot> _tasks;
  final StreamTracker? tracker;
  final StreamController<List<TaskSnapshot>> _tasksController =
      StreamController<List<TaskSnapshot>>.broadcast(sync: true);

  final Map<String, StreamController<Duration>> _elapsedControllers = {};

  int _nextId = 1;

  @override
  List<TaskSnapshot> get currentTasks => List.unmodifiable(_tasks);

  @override
  Stream<List<TaskSnapshot>> get tasksStream {
    final stream = _tasksController.stream;
    return tracker != null ? tracker!.track('tasksStream', stream) : stream;
  }

  @override
  Stream<Duration> elapsedStream(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) {
      return Stream.error(TaskNotFoundException(taskId));
    }
    final controller = _elapsedControllers.putIfAbsent(
      taskId,
      () => StreamController<Duration>.broadcast(sync: true),
    );
    final stream = controller.stream;
    return tracker != null
        ? tracker!.track('elapsedStream:$taskId', stream)
        : stream;
  }

  void _notifyTasks() {
    _tasksController.add(List.unmodifiable(_tasks));
  }

  /// Phát giá trị elapsed vào stream của đồng hồ [taskId] để phục vụ test UI.
  void emitElapsed(String taskId, Duration elapsed) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(elapsed: elapsed);
    }
    _elapsedControllers[taskId]?.add(elapsed);
  }

  /// Phát lỗi vào elapsedStream để kiểm thử phản ứng lỗi của UI.
  void emitElapsedError(String taskId, Object error) {
    _elapsedControllers[taskId]?.addError(error);
  }

  @override
  Future<TaskSnapshot> createTask({
    required String name,
    required int colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tên không được rỗng');
    }
    final task = TaskSnapshot(
      id: 'task_${_nextId++}',
      name: trimmed,
      colorValue: colorValue,
      createdAt: DateTime.now().toUtc(),
      status: TaskStatus.idle,
      elapsed: Duration.zero,
    );
    _tasks.add(task);
    _notifyTasks();
    return task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    _elapsedControllers[taskId]?.close();
    _elapsedControllers.remove(taskId);
    _notifyTasks();
  }

  @override
  Future<void> renameTask(String taskId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tên không được rỗng');
    }
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    _tasks[index] = _tasks[index].copyWith(name: trimmed);
    _notifyTasks();
  }

  @override
  Future<void> changeTaskColor(String taskId, int colorValue) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    _tasks[index] = _tasks[index].copyWith(colorValue: colorValue);
    _notifyTasks();
  }

  @override
  Future<void> start(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    if (_tasks[index].status != TaskStatus.idle) {
      throw InvalidTransitionException(
        taskId: taskId,
        action: 'start',
        status: _tasks[index].status,
      );
    }
    _tasks[index] = _tasks[index].copyWith(status: TaskStatus.running);
    _notifyTasks();
  }

  @override
  Future<void> pause(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    if (_tasks[index].status != TaskStatus.running) {
      throw InvalidTransitionException(
        taskId: taskId,
        action: 'pause',
        status: _tasks[index].status,
      );
    }
    _tasks[index] = _tasks[index].copyWith(status: TaskStatus.paused);
    _notifyTasks();
  }

  @override
  Future<void> resume(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    if (_tasks[index].status != TaskStatus.paused) {
      throw InvalidTransitionException(
        taskId: taskId,
        action: 'resume',
        status: _tasks[index].status,
      );
    }
    _tasks[index] = _tasks[index].copyWith(status: TaskStatus.running);
    _notifyTasks();
  }

  @override
  Future<void> reset(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    _tasks[index] = _tasks[index].copyWith(
      status: TaskStatus.idle,
      elapsed: Duration.zero,
      laps: const [],
    );
    _notifyTasks();
  }

  @override
  Future<Lap> lap(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) throw TaskNotFoundException(taskId);
    if (_tasks[index].status != TaskStatus.running) {
      throw InvalidTransitionException(
        taskId: taskId,
        action: 'lap',
        status: _tasks[index].status,
      );
    }
    final laps = List<Lap>.from(_tasks[index].laps);
    final number = laps.length + 1;
    final total = _tasks[index].elapsed;
    final split = laps.isEmpty ? total : total - laps.last.total;
    final delta = laps.isEmpty ? null : split - laps.last.split;
    final newLap = Lap(
      number: number,
      split: split,
      total: total,
      delta: delta,
      recordedAt: DateTime.now().toUtc(),
    );
    laps.add(newLap);
    _tasks[index] = _tasks[index].copyWith(laps: laps);
    _notifyTasks();
    return newLap;
  }

  @override
  Future<void> dispose() async {
    await _tasksController.close();
    for (final controller in _elapsedControllers.values) {
      await controller.close();
    }
    _elapsedControllers.clear();
  }
}
