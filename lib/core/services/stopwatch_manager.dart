import 'dart:async';

import '../debug/stream_tracker.dart';
import '../models/stopwatch_task.dart';
import '../storage/task_repository.dart';
import '../ticker/elapsed_tracker.dart';
import '../ticker/tick_source.dart';
import '../ticker/time_source.dart';
import 'stopwatch_service.dart';

/// Implementation của [StopwatchService]: nhiều đồng hồ chạy song song, độc
/// lập với nhau.
///
/// Thiết kế:
/// - Mỗi đồng hồ có một [ElapsedTracker] riêng nên chạy/dừng độc lập, và
///   elapsed tính theo mốc thời gian chứ không cộng dồn tick.
/// - Mọi đồng hồ dùng chung một [TickSource]. Một đồng hồ chỉ nghe tick khi nó
///   đang chạy VÀ có người nghe `elapsedStream` của nó, nên lúc không có đồng
///   hồ nào chạy trên màn hình thì cũng không có Timer nào.
/// - Lệnh được xếp hàng: lệnh sau chờ lệnh trước xong hẳn (kể cả phần lưu), nên
///   thứ tự luôn đúng và không bao giờ có hai lệnh chen nhau.
/// - Lệnh sửa đồng hồ cập nhật bộ nhớ và phát cho UI ngay, rồi mới lưu; lưu
///   lỗi thì hoàn tác. Vì sao: nút bấm phản hồi tức thì, thời điểm bấm không bị
///   trễ theo độ trễ lưu trữ; và nhờ xếp hàng, hoàn tác chỉ cần trả về đúng
///   trạng thái trước đó vì không có lệnh nào xen giữa.
/// - Tạo/xóa thì chờ lưu xong mới phát, để UI không thấy đồng hồ "hiện ra rồi
///   biến mất" khi lưu lỗi.
/// - Khôi phục sau khi khởi động lại dựa trên timestamp: đồng hồ đang chạy được
///   dựng lại từ `accumulated` và `runningSince` đã lưu, nên thời gian app bị
///   tắt cũng được tính.
/// - Hủy luồng an toàn: [dispose] chờ lệnh đang dở, hủy mọi subscription tick,
///   phát done cho mọi listener rồi mới dispose [TickSource] tự tạo. Sau đó
///   không còn Timer, không còn subscription, và không phát thêm sự kiện nào.
class StopwatchManager implements StopwatchService {
  /// Nhận mọi dependency từ bên ngoài (dependency injection): nơi lưu
  /// [repository], nguồn nhịp [tickSource], nguồn thời gian [timeSource]; nhờ
  /// vậy test thay được bằng bản giả, app chọn được lưu trên máy hay API.
  ///
  /// [initialTasks] là dữ liệu đã nạp từ [repository]. Vì sao không tự nạp
  /// trong constructor: constructor Dart không thể `await`. Việc đọc bất đồng
  /// bộ nằm ở [open], còn constructor chạy đồng bộ, nên không bao giờ có trạng
  /// thái "đã tạo nhưng chưa nạp xong".
  ///
  /// [tickSource] được truyền vào thì manager không dispose nó (nơi tạo tự
  /// quản lý); bỏ trống thì manager tự tạo và tự dispose.
  ///
  /// [tracker] (tùy chọn) đếm và ghi log subscription của `tasksStream` và
  /// `elapsedStream:<taskId>`; nó cũng được truyền cho [TickSource] tự tạo.
  /// Manager không dispose [tracker] vì nơi tạo (màn Debug) còn đọc log sau đó.
  StopwatchManager({
    required this._repository,
    List<StopwatchTask> initialTasks = const [],
    TickSource? tickSource,
    TimeSource? timeSource,
    this._tracker,
  }) : _tickSource = tickSource ?? TickSource(tracker: _tracker),
       _ownsTickSource = tickSource == null,
       _time = timeSource ?? SystemTimeSource() {
    for (final task in initialTasks) {
      _entries[task.id] = _newEntry(task);
    }
  }

  /// Cách tạo thường dùng: nạp dữ liệu từ [repository] rồi gọi constructor.
  ///
  /// Lỗi đọc dữ liệu: Future lỗi với [StorageException].
  static Future<StopwatchManager> open({
    required TaskRepository repository,
    TickSource? tickSource,
    TimeSource? timeSource,
    StreamTracker? tracker,
  }) async => StopwatchManager(
    repository: repository,
    initialTasks: await repository.loadAll(),
    tickSource: tickSource,
    timeSource: timeSource,
    tracker: tracker,
  );

  final TaskRepository _repository;
  final TickSource _tickSource;
  final bool _ownsTickSource;
  final TimeSource _time;
  final StreamTracker? _tracker;

  /// Map giữ thứ tự chèn nên danh sách luôn theo thứ tự tạo.
  final Map<String, _TaskEntry> _entries = {};
  final Set<_LatestValueSink<List<TaskSnapshot>>> _taskSinks = {};
  Future<void> _queueTail = Future.value();
  Future<void>? _disposeFuture;
  int _idCounter = 0;

  bool get _isDisposed => _disposeFuture != null;

  @override
  List<TaskSnapshot> get currentTasks => List.unmodifiable([
    for (final entry in _entries.values) entry.snapshot(),
  ]);

  @override
  late final Stream<List<TaskSnapshot>> tasksStream = _track(
    'tasksStream',
    Stream.multi((controller) {
      if (_isDisposed) {
        controller.close();
        return;
      }
      final sink = _LatestValueSink(controller);
      _taskSinks.add(sink);
      sink.emit(currentTasks);
      controller
        ..onCancel = () {
          _taskSinks.remove(sink);
        }
        ..onResume = () => sink.emit(currentTasks);
    }, isBroadcast: true),
  );

  @override
  Stream<Duration> elapsedStream(String taskId) => _track(
    'elapsedStream:$taskId',
    Stream.multi((controller) {
      final entry = _entries[taskId];
      if (_isDisposed) {
        controller.close();
      } else if (entry == null) {
        controller
          ..addError(TaskNotFoundException(taskId))
          ..close();
      } else {
        entry.addListener(controller);
      }
    }, isBroadcast: true),
  );

  Stream<T> _track<T>(String source, Stream<T> stream) =>
      _tracker?.track(source, stream) ?? stream;

  @override
  Future<TaskSnapshot> createTask({
    required String name,
    required int colorValue,
  }) => _enqueue(() async {
    final task = StopwatchTask(
      id: _nextId(),
      name: _checkName(name),
      colorValue: _checkColor(colorValue),
      createdAt: _time.now(),
    );
    await _repository.upsert(task);
    final entry = _newEntry(task);
    _entries[task.id] = entry;
    _emitTasks();
    return entry.snapshot();
  });

  @override
  Future<void> deleteTask(String taskId) => _enqueue(() async {
    final entry = _entryOf(taskId);
    await _repository.delete(taskId);
    _entries.remove(taskId);
    entry.close();
    _emitTasks();
  });

  @override
  Future<void> renameTask(String taskId, String name) =>
      _mutate(taskId, (entry) {
        entry.task = entry.task.copyWith(name: _checkName(name));
      });

  @override
  Future<void> changeTaskColor(String taskId, int colorValue) =>
      _mutate(taskId, (entry) {
        entry.task = entry.task.copyWith(colorValue: _checkColor(colorValue));
      });

  @override
  Future<void> start(String taskId) => _mutate(taskId, (entry) {
    _expectStatus(entry, 'start', TaskStatus.idle);
    _run(entry);
  });

  @override
  Future<void> pause(String taskId) => _mutate(taskId, (entry) {
    _expectStatus(entry, 'pause', TaskStatus.running);
    _halt(entry);
  });

  @override
  Future<void> resume(String taskId) => _mutate(taskId, (entry) {
    _expectStatus(entry, 'resume', TaskStatus.paused);
    _run(entry);
  });

  @override
  Future<void> reset(String taskId) => _mutate(taskId, _clear);

  @override
  Future<Lap> lap(String taskId) => _mutate(taskId, (entry) {
    _expectStatus(entry, 'lap', TaskStatus.running);
    final lap = _nextLap(entry.task.laps, entry.tracker.elapsed);
    entry.task = entry.task.copyWith(
      laps: [...entry.task.laps, lap],
      runningSince: entry.tracker.runningSince,
    );
    return lap;
  });

  @override
  Future<void> runAll() =>
      _mutateBatch((task) => task.status != TaskStatus.running, _run);

  @override
  Future<void> pauseAll() =>
      _mutateBatch((task) => task.status == TaskStatus.running, _halt);

  @override
  Future<void> resetAll() => _mutateBatch(
    (task) => task.status != TaskStatus.idle,
    (entry, _) => _clear(entry),
  );

  @override
  Future<void> deleteAll() => _enqueue(() async {
    if (_entries.isEmpty) return;
    await _repository.deleteAll([..._entries.keys]);
    final removed = [..._entries.values];
    _entries.clear();
    for (final entry in removed) {
      entry.close();
    }
    _emitTasks();
  });

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    await _queueTail;
    for (final entry in _entries.values) {
      entry.close();
    }
    final sinks = [..._taskSinks];
    _taskSinks.clear();
    for (final sink in sinks) {
      sink.close();
    }
    if (_ownsTickSource) await _tickSource.dispose();
    _tracker?.recordDispose('StopwatchManager');
  }

  /// Xếp [command] vào hàng đợi; mọi lỗi (kể cả lỗi ném đồng bộ trong
  /// [command]) đều trả qua Future.
  ///
  /// Vì sao đuôi hàng nuốt lỗi: lỗi đã được trả cho người gọi qua `result`;
  /// nếu để lỗi lan sang đuôi hàng thì mọi lệnh phía sau cũng hỏng theo.
  Future<T> _enqueue<T>(Future<T> Function() command) {
    if (_isDisposed) {
      return Future.error(StateError('StopwatchManager đã dispose.'));
    }
    final result = _queueTail.then((_) => command());
    _queueTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Lệnh sửa một đồng hồ: [apply] kiểm tra rồi sửa trạng thái trong bộ nhớ,
  /// UI được báo ngay, sau đó mới lưu; lưu lỗi thì hoàn tác và báo lại UI.
  /// [apply] không làm thay đổi gì (vd reset khi đang idle) thì không lưu.
  Future<T> _mutate<T>(String taskId, T Function(_TaskEntry entry) apply) =>
      _enqueue(() async {
        final entry = _entryOf(taskId);
        final previous = entry.task;
        final result = apply(entry);
        if (entry.task == previous) return result;
        entry.notifyChanged();
        _emitTasks();
        try {
          await _repository.upsert(entry.task);
        } catch (_) {
          entry.restore(previous);
          _emitTasks();
          rethrow;
        }
        return result;
      });

  /// Lệnh hàng loạt: áp [apply] cho mọi đồng hồ thỏa [inScope] tại CÙNG một
  /// mốc thời gian, báo UI một lần rồi ghi repository một lần; lưu lỗi thì
  /// hoàn tác cả lô và báo lại UI một lần, giống [_mutate] của lệnh đơn lẻ.
  ///
  /// Vì sao đọc mốc một lần ở đây rồi truyền xuống: mỗi đồng hồ tự đọc thời
  /// gian thì các mốc lệch nhau theo thứ tự duyệt. Vì sao phát và ghi một lần:
  /// UI rebuild một lần, không thấy "nửa lô", và cả lô cùng được lưu hoặc
  /// cùng không. Không có đồng hồ nào thuộc phạm vi thì không phát, không ghi.
  Future<void> _mutateBatch(
    bool Function(StopwatchTask task) inScope,
    void Function(_TaskEntry entry, TimeReading at) apply,
  ) => _enqueue(() async {
    final targets = [
      for (final entry in _entries.values)
        if (inScope(entry.task)) entry,
    ];
    if (targets.isEmpty) return;
    final at = _time.read();
    final previous = [for (final entry in targets) (entry, entry.task)];
    for (final entry in targets) {
      apply(entry, at);
      entry.notifyChanged();
    }
    _emitTasks();
    try {
      await _repository.upsertAll([for (final entry in targets) entry.task]);
    } catch (_) {
      for (final (entry, task) in previous) {
        entry.restore(task);
      }
      _emitTasks();
      rethrow;
    }
  });

  /// idle hoặc paused -> running, bắt đầu tại [at] (bỏ trống: lúc gọi).
  static void _run(_TaskEntry entry, [TimeReading? at]) {
    entry.tracker.start(at);
    entry.task = entry.task.copyWith(
      status: TaskStatus.running,
      runningSince: entry.tracker.runningSince,
    );
  }

  /// running -> paused, dừng tại [at] (bỏ trống: lúc gọi).
  static void _halt(_TaskEntry entry, [TimeReading? at]) {
    entry.task = entry.task.copyWith(
      status: TaskStatus.paused,
      accumulated: entry.tracker.stop(at),
      clearRunningSince: true,
    );
  }

  /// Về idle: elapsed = 0 và xóa hết lap.
  static void _clear(_TaskEntry entry) {
    entry.tracker.reset();
    entry.task = entry.task.copyWith(
      status: TaskStatus.idle,
      accumulated: Duration.zero,
      clearRunningSince: true,
      laps: const [],
    );
  }

  /// [Lap.split] = total hiện tại trừ total của lap trước; [Lap.delta] = split
  /// này trừ split của lap trước.
  ///
  /// Split được kẹp về 0 nếu total nhỏ hơn lap trước (chỉ xảy ra khi giờ hệ
  /// thống bị chỉnh lùi lúc app tắt), để Lap luôn hợp lệ.
  Lap _nextLap(List<Lap> laps, Duration total) {
    final previous = laps.isEmpty ? null : laps.last;
    final sincePrevious = total - (previous?.total ?? Duration.zero);
    final split = sincePrevious.isNegative ? Duration.zero : sincePrevious;
    return Lap(
      number: laps.length + 1,
      split: split,
      total: total,
      delta: previous == null ? null : split - previous.split,
      recordedAt: _time.now(),
    );
  }

  _TaskEntry _newEntry(StopwatchTask task) =>
      _TaskEntry(task, _time, _tickSource);

  _TaskEntry _entryOf(String taskId) =>
      _entries[taskId] ?? (throw TaskNotFoundException(taskId));

  void _emitTasks() {
    if (_taskSinks.isEmpty) return;
    final tasks = currentTasks;
    for (final sink in _taskSinks) {
      sink.emit(tasks);
    }
  }

  /// Vì sao ghép thời điểm tạo với bộ đếm: không cần package uuid mà vẫn không
  /// trùng. Bộ đếm phân biệt các đồng hồ tạo trong cùng một micro giây, còn
  /// thời điểm phân biệt giữa các lần mở app.
  String _nextId() {
    final stamp = _time.now().microsecondsSinceEpoch.toRadixString(36);
    String id;
    do {
      id = 'task-$stamp-${_idCounter++}';
    } while (_entries.containsKey(id));
    return id;
  }

  static void _expectStatus(
    _TaskEntry entry,
    String action,
    TaskStatus expected,
  ) {
    final status = entry.task.status;
    if (status != expected) {
      throw InvalidTransitionException(
        taskId: entry.task.id,
        action: action,
        status: status,
      );
    }
  }

  static String _checkName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tên không được rỗng');
    }
    return trimmed;
  }

  static int _checkColor(int colorValue) {
    if (colorValue < 0 || colorValue > 0xFFFFFFFF) {
      throw ArgumentError.value(
        colorValue,
        'colorValue',
        'Phải là ARGB 32-bit',
      );
    }
    return colorValue;
  }
}

/// Trạng thái trong phiên của một đồng hồ: dữ liệu lưu trữ, bộ đo thời gian
/// và những ai đang nghe elapsed của nó.
class _TaskEntry {
  _TaskEntry(this.task, this._time, this._tickSource)
    : tracker = _trackerFor(task, _time);

  /// Dạng lưu trữ; các trường thời gian được cập nhật theo [tracker] sau mỗi
  /// lệnh.
  StopwatchTask task;
  ElapsedTracker tracker;
  final TimeSource _time;
  final TickSource _tickSource;
  final Set<_LatestValueSink<Duration>> _elapsedSinks = {};
  StreamSubscription<int>? _tickSubscription;

  static ElapsedTracker _trackerFor(StopwatchTask task, TimeSource time) =>
      ElapsedTracker(
        timeSource: time,
        accumulated: task.accumulated,
        runningSince: task.runningSince,
      );

  TaskSnapshot snapshot() => TaskSnapshot(
    id: task.id,
    name: task.name,
    colorValue: task.colorValue,
    createdAt: task.createdAt,
    status: task.status,
    elapsed: tracker.elapsed,
    laps: task.laps,
  );

  void addListener(MultiStreamController<Duration> controller) {
    final sink = _LatestValueSink(controller);
    _elapsedSinks.add(sink);
    sink.emit(tracker.elapsed);
    controller
      ..onCancel = () {
        _elapsedSinks.remove(sink);
        _syncTicking();
      }
      ..onResume = () => sink.emit(tracker.elapsed);
    _syncTicking();
  }

  /// Gọi sau mỗi lần đổi trạng thái: phát elapsed mới một lần và bật/tắt việc
  /// nghe tick cho đúng trạng thái.
  void notifyChanged() {
    _emitElapsed();
    _syncTicking();
  }

  /// Trả về đúng trạng thái [previous] khi lưu thất bại.
  void restore(StopwatchTask previous) {
    task = previous;
    tracker = _trackerFor(previous, _time);
    notifyChanged();
  }

  /// Hủy nghe tick và phát done cho mọi listener.
  ///
  /// Vì sao copy danh sách trước khi đóng: đóng có thể kích hoạt `onCancel`
  /// ngay lập tức, mà `onCancel` lại xóa khỏi chính tập đang duyệt.
  void close() {
    _tickSubscription?.cancel();
    _tickSubscription = null;
    final sinks = [..._elapsedSinks];
    _elapsedSinks.clear();
    for (final sink in sinks) {
      sink.close();
    }
  }

  void _emitElapsed() {
    if (_elapsedSinks.isEmpty) return;
    final elapsed = tracker.elapsed;
    for (final sink in _elapsedSinks) {
      sink.emit(elapsed);
    }
  }

  /// Vì sao chỉ nghe tick khi đang chạy VÀ có người nghe: đồng hồ dừng thì
  /// elapsed không đổi, không ai nghe thì không cần tính. Hủy subscription còn
  /// giúp [TickSource] tự tắt Timer khi không còn đồng hồ nào cần.
  void _syncTicking() {
    if (tracker.isRunning && _elapsedSinks.isNotEmpty) {
      _tickSubscription ??= _tickSource.ticks.listen((_) => _emitElapsed());
    } else {
      _tickSubscription?.cancel();
      _tickSubscription = null;
    }
  }
}

/// Một listener của stream kiểu "giá trị mới nhất" tạo bằng [Stream.multi].
///
/// Vì sao bỏ qua khi listener đang pause: giá trị cũ không còn ý nghĩa, dồn lại
/// thì lúc resume UI nhận một loạt sự kiện thừa; thay vào đó resume nhận ngay
/// giá trị mới nhất. Vì sao bỏ giá trị trùng: tránh UI rebuild khi không có gì
/// thay đổi (vd elapsed lúc đang pause).
class _LatestValueSink<T> {
  _LatestValueSink(this._controller);

  final MultiStreamController<T> _controller;
  bool _hasValue = false;
  T? _last;

  void emit(T value) {
    if (_controller.isPaused) return;
    if (_hasValue && value == _last) return;
    _hasValue = true;
    _last = value;
    _controller.add(value);
  }

  void close() => _controller.closeSync();
}
