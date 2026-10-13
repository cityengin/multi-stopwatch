import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/services/stopwatch_manager.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';
import 'package:multi_stopwatch/core/ticker/tick_source.dart';

import '../support/fake_time_sources.dart';
import '../support/flaky_task_repository.dart';

const _blue = 0xFF2196F3;
const _tick = TickSource.defaultInterval;

/// Chạy hết microtask rồi trả kết quả của [future] (hoặc ném lỗi của nó).
T _settle<T>(FakeAsync async, Future<T> future) {
  late T value;
  Object? error;
  var done = false;
  future.then<void>(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  if (!done) fail('Future chưa hoàn thành');
  final failure = error;
  if (failure != null) throw failure;
  return value;
}

/// Chạy hết microtask và trả về lỗi mà [future] phải hoàn thành cùng.
Object _errorOf(FakeAsync async, Future<void> future) {
  Object? error;
  var done = false;
  future.then<void>(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  expect(done, isTrue, reason: 'Future chưa hoàn thành');
  expect(error, isNotNull, reason: 'Future lẽ ra phải lỗi');
  return error!;
}

/// Ghi lại mọi sự kiện của một stream.
class _Recorder<T> {
  _Recorder(Stream<T> stream) {
    subscription = stream.listen(
      values.add,
      onError: errors.add,
      onDone: () => done = true,
    );
  }

  final values = <T>[];
  final errors = <Object>[];
  var done = false;
  late final StreamSubscription<T> subscription;
}

StopwatchManager _open(
  FakeAsync async, {
  TaskRepository? repository,
  TickSource? tickSource,
}) => _settle(
  async,
  StopwatchManager.open(
    repository: repository ?? InMemoryTaskRepository(),
    tickSource: tickSource,
    timeSource: FakeAsyncTimeSource(async),
  ),
);

String _create(
  FakeAsync async,
  StopwatchService service, [
  String name = 'Đồng hồ',
]) => _settle(async, service.createTask(name: name, colorValue: _blue)).id;

TaskSnapshot _snapshot(StopwatchService service, String id) =>
    service.currentTasks.singleWhere((task) => task.id == id);

void main() {
  group('tạo, sửa, xóa', () {
    test('mở với repository rỗng: chưa có đồng hồ, tasksStream phát list rỗng '
        'làm sự kiện đầu', () {
      fakeAsync((async) {
        final manager = _open(async);
        final tasks = _Recorder(manager.tasksStream);
        async.flushMicrotasks();

        expect(manager.currentTasks, isEmpty);
        expect(tasks.values, [isEmpty]);
        expect(manager.tasksStream.isBroadcast, isTrue);
        _settle(async, manager.dispose());
      });
    });

    test('createTask: trim tên, ở trạng thái idle, đã lưu và được phát', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final tasks = _Recorder(manager.tasksStream);
        final created = _settle(
          async,
          manager.createTask(name: '  Chạy bộ  ', colorValue: _blue),
        );

        expect(created.name, 'Chạy bộ');
        expect(created.colorValue, _blue);
        expect(created.status, TaskStatus.idle);
        expect(created.elapsed, Duration.zero);
        expect(created.laps, isEmpty);
        expect(manager.currentTasks, [created]);
        expect(tasks.values.last, [created]);
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.id, created.id);
        expect(saved.name, 'Chạy bộ');
        _settle(async, manager.dispose());
      });
    });

    test('createTask: tên rỗng hoặc màu sai báo ArgumentError qua Future', () {
      fakeAsync((async) {
        final manager = _open(async);

        expect(
          _errorOf(async, manager.createTask(name: '   ', colorValue: _blue)),
          isArgumentError,
        );
        expect(
          _errorOf(async, manager.createTask(name: 'x', colorValue: -1)),
          isArgumentError,
        );
        expect(
          _errorOf(async, manager.createTask(name: 'x', colorValue: 1 << 32)),
          isArgumentError,
        );
        expect(manager.currentTasks, isEmpty);
        _settle(async, manager.dispose());
      });
    });

    test('renameTask và changeTaskColor: cập nhật, lưu, kiểm tra tham số', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        _settle(async, manager.renameTask(id, '  Đọc sách '));
        _settle(async, manager.changeTaskColor(id, 0xFFFF0000));

        expect(_snapshot(manager, id).name, 'Đọc sách');
        expect(_snapshot(manager, id).colorValue, 0xFFFF0000);
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.name, 'Đọc sách');
        expect(saved.colorValue, 0xFFFF0000);
        expect(_errorOf(async, manager.renameTask(id, '')), isArgumentError);
        expect(
          _errorOf(async, manager.changeTaskColor(id, -5)),
          isArgumentError,
        );
        expect(_snapshot(manager, id).name, 'Đọc sách');
        _settle(async, manager.dispose());
      });
    });

    test('deleteTask: xóa khỏi danh sách và repository, elapsedStream của nó '
        'phát done, không còn Timer', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final keep = _create(async, manager, 'Giữ');
        final drop = _create(async, manager, 'Xóa');
        _settle(async, manager.start(drop));
        final elapsed = _Recorder(manager.elapsedStream(drop));
        async.elapse(const Duration(milliseconds: 100));
        _settle(async, manager.deleteTask(drop));

        expect(elapsed.done, isTrue);
        expect(manager.currentTasks.map((t) => t.id), [keep]);
        expect(_settle(async, repository.loadAll()).map((t) => t.id), [keep]);
        expect(async.periodicTimerCount, 0);
        _settle(async, manager.dispose());
      });
    });

    test('taskId không tồn tại: mọi lệnh báo TaskNotFoundException, '
        'elapsedStream phát lỗi rồi done', () {
      fakeAsync((async) {
        final manager = _open(async);
        final commands = <Future<void> Function()>[
          () => manager.deleteTask('khong-co'),
          () => manager.renameTask('khong-co', 'x'),
          () => manager.changeTaskColor('khong-co', _blue),
          () => manager.start('khong-co'),
          () => manager.pause('khong-co'),
          () => manager.resume('khong-co'),
          () => manager.reset('khong-co'),
          () => manager.lap('khong-co'),
        ];

        for (final command in commands) {
          expect(
            _errorOf(async, command()),
            isA<TaskNotFoundException>().having(
              (e) => e.taskId,
              'taskId',
              'khong-co',
            ),
          );
        }
        final elapsed = _Recorder(manager.elapsedStream('khong-co'));
        async.flushMicrotasks();
        expect(elapsed.values, isEmpty);
        expect(elapsed.errors.single, isA<TaskNotFoundException>());
        expect(elapsed.done, isTrue);
        _settle(async, manager.dispose());
      });
    });
  });

  group('chuyển trạng thái', () {
    test('start, pause, resume: elapsed chỉ tính lúc chạy và được lưu', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);

        _settle(async, manager.start(id));
        async.elapse(const Duration(milliseconds: 1500));
        expect(_snapshot(manager, id).status, TaskStatus.running);
        expect(
          _snapshot(manager, id).elapsed,
          const Duration(milliseconds: 1500),
        );

        _settle(async, manager.pause(id));
        async.elapse(const Duration(seconds: 10));
        expect(_snapshot(manager, id).status, TaskStatus.paused);
        expect(
          _snapshot(manager, id).elapsed,
          const Duration(milliseconds: 1500),
        );
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.status, TaskStatus.paused);
        expect(saved.accumulated, const Duration(milliseconds: 1500));

        _settle(async, manager.resume(id));
        async.elapse(const Duration(milliseconds: 500));
        expect(_snapshot(manager, id).status, TaskStatus.running);
        expect(_snapshot(manager, id).elapsed, const Duration(seconds: 2));
        _settle(async, manager.dispose());
      });
    });

    test('reset từ running hoặc paused về idle, xóa lap; '
        'reset khi đang idle không lỗi', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.lap(id));
        async.elapse(const Duration(seconds: 1));

        _settle(async, manager.reset(id));
        async.elapse(const Duration(seconds: 1));
        final afterRunning = _snapshot(manager, id);
        expect(afterRunning.status, TaskStatus.idle);
        expect(afterRunning.elapsed, Duration.zero);
        expect(afterRunning.laps, isEmpty);
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.status, TaskStatus.idle);
        expect(saved.laps, isEmpty);

        _settle(async, manager.start(id));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.pause(id));
        _settle(async, manager.reset(id));
        expect(_snapshot(manager, id).status, TaskStatus.idle);
        expect(_snapshot(manager, id).elapsed, Duration.zero);

        _settle(async, manager.reset(id));
        expect(_snapshot(manager, id).status, TaskStatus.idle);
        _settle(async, manager.dispose());
      });
    });

    test('thao tác sai trạng thái báo InvalidTransitionException '
        'và không đổi gì', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        Matcher invalid(String action, TaskStatus status) =>
            isA<InvalidTransitionException>()
                .having((e) => e.taskId, 'taskId', id)
                .having((e) => e.action, 'action', action)
                .having((e) => e.status, 'status', status);

        expect(
          _errorOf(async, manager.pause(id)),
          invalid('pause', TaskStatus.idle),
        );
        expect(
          _errorOf(async, manager.resume(id)),
          invalid('resume', TaskStatus.idle),
        );
        expect(
          _errorOf(async, manager.lap(id)),
          invalid('lap', TaskStatus.idle),
        );

        _settle(async, manager.start(id));
        expect(
          _errorOf(async, manager.start(id)),
          invalid('start', TaskStatus.running),
        );
        expect(
          _errorOf(async, manager.resume(id)),
          invalid('resume', TaskStatus.running),
        );

        _settle(async, manager.pause(id));
        expect(
          _errorOf(async, manager.start(id)),
          invalid('start', TaskStatus.paused),
        );
        expect(
          _errorOf(async, manager.pause(id)),
          invalid('pause', TaskStatus.paused),
        );
        expect(
          _errorOf(async, manager.lap(id)),
          invalid('lap', TaskStatus.paused),
        );
        expect(_snapshot(manager, id).status, TaskStatus.paused);
        _settle(async, manager.dispose());
      });
    });
  });

  group('lap', () {
    test('ghi lap time (split), total và chênh lệch so với lap trước', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        _settle(async, manager.start(id));

        async.elapse(const Duration(seconds: 1));
        final lap1 = _settle(async, manager.lap(id));
        async.elapse(const Duration(milliseconds: 1500));
        final lap2 = _settle(async, manager.lap(id));
        async.elapse(const Duration(milliseconds: 500));
        final lap3 = _settle(async, manager.lap(id));

        expect([lap1.number, lap2.number, lap3.number], [1, 2, 3]);
        expect(
          [lap1.split, lap2.split, lap3.split],
          const [
            Duration(seconds: 1),
            Duration(milliseconds: 1500),
            Duration(milliseconds: 500),
          ],
        );
        expect(
          [lap1.total, lap2.total, lap3.total],
          const [
            Duration(seconds: 1),
            Duration(milliseconds: 2500),
            Duration(seconds: 3),
          ],
        );
        expect(
          [lap1.delta, lap2.delta, lap3.delta],
          const [null, Duration(milliseconds: 500), Duration(seconds: -1)],
        );
        expect(_snapshot(manager, id).laps, [lap1, lap2, lap3]);
        expect(_settle(async, repository.loadAll()).single.laps, [
          lap1,
          lap2,
          lap3,
        ]);
        _settle(async, manager.dispose());
      });
    });

    test('lap sau pause/resume chỉ tính thời gian chạy', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.pause(id));
        async.elapse(const Duration(seconds: 5));
        _settle(async, manager.resume(id));
        async.elapse(const Duration(seconds: 1));

        final lap = _settle(async, manager.lap(id));
        expect(lap.total, const Duration(seconds: 2));
        expect(lap.split, const Duration(seconds: 2));
        expect(lap.delta, isNull);
        _settle(async, manager.dispose());
      });
    });
  });

  group('elapsedStream', () {
    test('sự kiện đầu là elapsed hiện tại; đồng hồ không chạy thì không có '
        'Timer', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        final elapsed = _Recorder(manager.elapsedStream(id));
        async.elapse(const Duration(seconds: 1));

        expect(elapsed.values, [Duration.zero]);
        expect(async.periodicTimerCount, 0);
        expect(manager.elapsedStream(id).isBroadcast, isTrue);
        _settle(async, manager.dispose());
      });
    });

    test('đang chạy thì phát theo tick đúng elapsed thật; pause phát giá trị '
        'cuối một lần rồi ngừng', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        final elapsed = _Recorder(manager.elapsedStream(id));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.pause(id));
        async.elapse(const Duration(seconds: 1));

        expect(elapsed.values.first, Duration.zero);
        expect(elapsed.values.sublist(1, elapsed.values.length - 1), [
          for (var i = 1; i <= 30; i++) _tick * i,
        ]);
        expect(elapsed.values.last, const Duration(seconds: 1));
        expect(async.periodicTimerCount, 0);
        _settle(async, manager.dispose());
      });
    });

    test('không phát lặp giá trị trùng khi elapsed không đổi', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        async.elapse(const Duration(seconds: 2));
        _settle(async, manager.pause(id));
        final elapsed = _Recorder(manager.elapsedStream(id));
        _settle(async, manager.renameTask(id, 'Tên mới'));
        _settle(async, manager.changeTaskColor(id, 0xFF00FF00));
        async.elapse(const Duration(seconds: 1));

        expect(elapsed.values, [const Duration(seconds: 2)]);
        _settle(async, manager.dispose());
      });
    });

    test('nhiều listener cùng nhận; hủy listener cuối thì TickSource tắt '
        'Timer nhưng đồng hồ vẫn chạy', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        final first = _Recorder(manager.elapsedStream(id));
        final second = _Recorder(manager.elapsedStream(id));
        async.elapse(const Duration(milliseconds: 100));

        expect(first.values, [Duration.zero, _tick, _tick * 2, _tick * 3]);
        expect(second.values, first.values);
        expect(async.periodicTimerCount, 1);
        first.subscription.cancel();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 1);
        second.subscription.cancel();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);

        async.elapse(const Duration(seconds: 1));
        expect(_snapshot(manager, id).status, TaskStatus.running);
        expect(
          _snapshot(manager, id).elapsed,
          const Duration(milliseconds: 1100),
        );
        _settle(async, manager.dispose());
      });
    });

    test('listener đang pause không bị dồn tick; resume nhận ngay giá trị '
        'mới nhất', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        final elapsed = _Recorder(manager.elapsedStream(id));
        async.elapse(const Duration(milliseconds: 100));
        expect(elapsed.values, hasLength(4));

        elapsed.subscription.pause();
        async.elapse(const Duration(seconds: 1));
        expect(elapsed.values, hasLength(4));
        elapsed.subscription.resume();
        async.flushMicrotasks();

        expect(elapsed.values, hasLength(5));
        expect(elapsed.values.last, const Duration(milliseconds: 1100));
        _settle(async, manager.dispose());
      });
    });
  });

  group('chạy song song', () {
    test('3 đồng hồ chạy độc lập, mỗi cái một elapsedStream, dùng chung một '
        'Timer', () {
      fakeAsync((async) {
        final manager = _open(async);
        final a = _create(async, manager, 'A');
        final b = _create(async, manager, 'B');
        final c = _create(async, manager, 'C');

        _settle(async, manager.start(a));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.start(b));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.start(c));
        final recA = _Recorder(manager.elapsedStream(a));
        final recB = _Recorder(manager.elapsedStream(b));
        final recC = _Recorder(manager.elapsedStream(c));
        async.elapse(const Duration(seconds: 1));
        _settle(async, manager.pause(b));
        _settle(async, manager.lap(a));
        async.elapse(const Duration(seconds: 2));

        expect(_snapshot(manager, a).elapsed, const Duration(seconds: 5));
        expect(_snapshot(manager, b).elapsed, const Duration(seconds: 2));
        expect(_snapshot(manager, b).status, TaskStatus.paused);
        expect(_snapshot(manager, c).elapsed, const Duration(seconds: 3));
        expect(async.periodicTimerCount, 1);
        expect(recB.values.last, const Duration(seconds: 2));
        expect(recA.values.last - recC.values.last, const Duration(seconds: 2));
        expect(_snapshot(manager, a).laps.single.total, Duration(seconds: 3));
        expect(_snapshot(manager, b).laps, isEmpty);
        expect(_snapshot(manager, c).laps, isEmpty);

        final pausedEvents = recB.values.length;
        async.elapse(const Duration(seconds: 1));
        expect(recB.values, hasLength(pausedEvents));

        _settle(async, manager.reset(a));
        expect(_snapshot(manager, a).status, TaskStatus.idle);
        expect(_snapshot(manager, a).elapsed, Duration.zero);
        expect(_snapshot(manager, b).elapsed, const Duration(seconds: 2));
        expect(_snapshot(manager, c).elapsed, const Duration(seconds: 4));
        expect(recA.values.last, Duration.zero);
        expect(async.periodicTimerCount, 1);

        _settle(async, manager.pause(c));
        expect(async.periodicTimerCount, 0);
        _settle(async, manager.dispose());
      });
    });
  });

  group('tasksStream', () {
    test('chỉ phát khi đổi trạng thái, không phát theo tick', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        final tasks = _Recorder(manager.tasksStream);
        async.flushMicrotasks();
        expect(tasks.values, hasLength(1));

        _settle(async, manager.start(id));
        expect(tasks.values, hasLength(2));
        async.elapse(const Duration(seconds: 5));
        expect(tasks.values, hasLength(2));
        expect(async.periodicTimerCount, 0);

        _settle(async, manager.lap(id));
        expect(tasks.values, hasLength(3));
        expect(tasks.values.last.single.laps, hasLength(1));
        _settle(async, manager.pause(id));
        expect(tasks.values, hasLength(4));
        expect(tasks.values.last.single.status, TaskStatus.paused);
        _settle(async, manager.dispose());
      });
    });
  });

  group('lưu trữ', () {
    test('mở lại từ repository: đồng hồ đang chạy được cộng cả thời gian app '
        'bị tắt, đồng hồ pause giữ nguyên', () {
      fakeAsync((async) {
        final now = FakeAsyncTimeSource(async).now();
        final repository = InMemoryTaskRepository([
          StopwatchTask(
            id: 'run',
            name: 'Đang chạy',
            colorValue: _blue,
            createdAt: now.subtract(const Duration(hours: 1)),
            status: TaskStatus.running,
            accumulated: const Duration(seconds: 5),
            runningSince: now.subtract(const Duration(minutes: 10)),
          ),
          StopwatchTask(
            id: 'paused',
            name: 'Tạm dừng',
            colorValue: _blue,
            createdAt: now.subtract(const Duration(hours: 1)),
            status: TaskStatus.paused,
            accumulated: const Duration(seconds: 42),
          ),
        ]);
        final manager = _open(async, repository: repository);

        expect(manager.currentTasks.map((t) => t.id), ['run', 'paused']);
        expect(_snapshot(manager, 'run').status, TaskStatus.running);
        expect(
          _snapshot(manager, 'run').elapsed,
          const Duration(minutes: 10, seconds: 5),
        );
        expect(_snapshot(manager, 'paused').elapsed, Duration(seconds: 42));
        async.elapse(const Duration(seconds: 2));
        expect(
          _snapshot(manager, 'run').elapsed,
          const Duration(minutes: 10, seconds: 7),
        );
        expect(_snapshot(manager, 'paused').elapsed, Duration(seconds: 42));
        _settle(async, manager.dispose());
      });
    });

    test('lưu thất bại: Future lỗi StorageException và trạng thái quay về '
        'như trước', () {
      fakeAsync((async) {
        final repository = FlakyTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        async.elapse(const Duration(seconds: 1));
        final tasks = _Recorder(manager.tasksStream);
        async.flushMicrotasks();
        repository.failWrites = true;

        expect(_errorOf(async, manager.pause(id)), isA<StorageException>());
        expect(tasks.values.map((list) => list.single.status), [
          TaskStatus.running,
          TaskStatus.paused,
          TaskStatus.running,
        ]);
        async.elapse(const Duration(seconds: 1));
        expect(_snapshot(manager, id).status, TaskStatus.running);
        expect(_snapshot(manager, id).elapsed, const Duration(seconds: 2));

        expect(
          _errorOf(async, manager.renameTask(id, 'Mới')),
          isA<StorageException>(),
        );
        expect(_snapshot(manager, id).name, 'Đồng hồ');
        expect(_errorOf(async, manager.lap(id)), isA<StorageException>());
        expect(_snapshot(manager, id).laps, isEmpty);
        expect(
          _errorOf(async, manager.createTask(name: 'Khác', colorValue: _blue)),
          isA<StorageException>(),
        );
        expect(
          _errorOf(async, manager.deleteTask(id)),
          isA<StorageException>(),
        );
        expect(manager.currentTasks, hasLength(1));

        repository.failWrites = false;
        _settle(async, manager.pause(id));
        expect(_snapshot(manager, id).elapsed, const Duration(seconds: 2));
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.status, TaskStatus.paused);
        expect(saved.accumulated, const Duration(seconds: 2));
        _settle(async, manager.dispose());
      });
    });

    test('lệnh gọi liên tiếp không chờ nhau vẫn chạy tuần tự đúng thứ tự', () {
      fakeAsync((async) {
        final repository = FlakyTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        repository.writeDelay = const Duration(milliseconds: 100);

        final started = manager.start(id);
        final lapped = manager.lap(id);
        final paused = manager.pause(id);
        async.elapse(const Duration(seconds: 1));

        _settle(async, started);
        expect(_settle(async, lapped).total, Duration(milliseconds: 100));
        _settle(async, paused);
        expect(_snapshot(manager, id).status, TaskStatus.paused);
        expect(
          _snapshot(manager, id).elapsed,
          const Duration(milliseconds: 200),
        );
        _settle(async, manager.dispose());
      });
    });

    test('lệnh gọi sau deleteTask đang chờ lưu thấy đồng hồ đã bị xóa', () {
      fakeAsync((async) {
        final repository = FlakyTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        repository.writeDelay = const Duration(milliseconds: 100);

        final deleted = manager.deleteTask(id);
        final renamed = manager.renameTask(id, 'Muộn');
        async.elapse(const Duration(seconds: 1));

        _settle(async, deleted);
        expect(_errorOf(async, renamed), isA<TaskNotFoundException>());
        _settle(async, manager.dispose());
      });
    });
  });

  group('dispose', () {
    test('idempotent, đóng mọi stream, không còn Timer; lệnh và listen sau '
        'đó đều bị từ chối', () {
      fakeAsync((async) {
        final manager = _open(async);
        final id = _create(async, manager);
        _settle(async, manager.start(id));
        final tasks = _Recorder(manager.tasksStream);
        final elapsed = _Recorder(manager.elapsedStream(id));
        async.elapse(const Duration(milliseconds: 100));

        final first = manager.dispose();
        final second = manager.dispose();
        expect(identical(first, second), isTrue);
        _settle(async, first);

        expect(tasks.done, isTrue);
        expect(elapsed.done, isTrue);
        expect(async.periodicTimerCount, 0);
        expect(_errorOf(async, manager.pause(id)), isStateError);
        expect(
          _errorOf(async, manager.createTask(name: 'x', colorValue: _blue)),
          isStateError,
        );
        final lateTasks = _Recorder(manager.tasksStream);
        final lateElapsed = _Recorder(manager.elapsedStream(id));
        async.flushMicrotasks();
        expect(lateTasks.done, isTrue);
        expect(lateTasks.values, isEmpty);
        expect(lateElapsed.done, isTrue);
        expect(lateElapsed.values, isEmpty);
      });
    });

    test('không tự pause đồng hồ đang chạy: lần mở sau vẫn chạy tiếp', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository();
        final first = _open(async, repository: repository);
        final id = _create(async, first);
        _settle(async, first.start(id));
        async.elapse(const Duration(seconds: 3));
        _settle(async, first.dispose());
        async.elapse(const Duration(seconds: 7));

        final second = _open(async, repository: repository);
        expect(_snapshot(second, id).status, TaskStatus.running);
        expect(_snapshot(second, id).elapsed, const Duration(seconds: 10));
        _settle(async, second.dispose());
      });
    });

    test('chờ lệnh đang dở lưu xong rồi mới hoàn thành', () {
      fakeAsync((async) {
        final repository = FlakyTaskRepository();
        final manager = _open(async, repository: repository);
        final id = _create(async, manager);
        repository.writeDelay = const Duration(milliseconds: 500);

        final started = manager.start(id);
        var disposed = false;
        manager.dispose().then((_) => disposed = true);
        async.elapse(const Duration(milliseconds: 200));
        expect(disposed, isFalse);
        async.elapse(const Duration(milliseconds: 400));
        expect(disposed, isTrue);

        _settle(async, started);
        final saved = _settle(async, repository.loadAll()).single;
        expect(saved.status, TaskStatus.running);
      });
    });

    test('TickSource truyền từ ngoài vào thì không bị dispose theo', () {
      fakeAsync((async) {
        final ticks = TickSource();
        final manager = _open(async, tickSource: ticks);
        _settle(async, manager.dispose());

        final received = _Recorder(ticks.ticks);
        async.elapse(const Duration(milliseconds: 100));
        expect(received.done, isFalse);
        expect(received.values, isNotEmpty);
        received.subscription.cancel();
        _settle(async, ticks.dispose());
      });
    });
  });
}
