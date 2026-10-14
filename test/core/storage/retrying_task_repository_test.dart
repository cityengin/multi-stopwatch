import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/retrying_task_repository.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';

import '../support/task_repository_contract.dart';

/// Repository luôn ném lỗi lập trình (không phải lỗi I/O) và đếm số lần gọi.
class _BrokenRepository implements TaskRepository {
  int calls = 0;

  @override
  Future<List<StopwatchTask>> loadAll() async => throw StateError('hỏng');

  @override
  Future<void> upsert(StopwatchTask task) async {
    calls++;
    throw StateError('hỏng');
  }

  @override
  Future<void> delete(String taskId) async => throw StateError('hỏng');

  @override
  Future<void> upsertAll(Iterable<StopwatchTask> tasks) async =>
      throw StateError('hỏng');

  @override
  Future<void> deleteAll(Iterable<String> taskIds) async =>
      throw StateError('hỏng');
}

void main() {
  runTaskRepositoryContract(
    () async => RetryingTaskRepository(InMemoryTaskRepository()),
  );

  group('RetryingTaskRepository', () {
    test('lỗi tạm thời: thử lại với thời gian chờ tăng dần rồi thành công', () {
      fakeAsync((async) {
        final api = InMemoryTaskRepository()..failNext(2);
        final retries = <(int, int)>[];
        final repository = RetryingTaskRepository(
          api,
          initialDelay: const Duration(milliseconds: 100),
          onRetry: (attempt, _) =>
              retries.add((attempt, async.elapsed.inMilliseconds)),
        );

        var saved = false;
        repository.upsert(contractTask('a')).then((_) => saved = true);
        async.elapse(const Duration(milliseconds: 299));
        expect(saved, isFalse);
        async.elapse(const Duration(milliseconds: 1));

        expect(saved, isTrue);
        expect(retries, [(2, 0), (3, 100)]);
        List<String>? ids;
        api.loadAll().then((tasks) => ids = [for (final t in tasks) t.id]);
        async.flushMicrotasks();
        expect(ids, ['a']);
      });
    });

    test('lỗi kéo dài: hết lượt thử thì báo StorageException của lần cuối', () {
      fakeAsync((async) {
        final api = InMemoryTaskRepository()..failNext(3);
        final repository = RetryingTaskRepository(
          api,
          initialDelay: const Duration(milliseconds: 100),
        );

        Object? error;
        repository
            .upsert(contractTask('a'))
            .catchError((Object e) => error = e);
        async.elapse(const Duration(milliseconds: 299));
        expect(error, isNull);
        async.elapse(const Duration(milliseconds: 1));

        expect(error, isA<StorageException>());
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('upsertAll và deleteAll được thử lại nguyên cả lô', () {
      fakeAsync((async) {
        final api = InMemoryTaskRepository(initial: [contractTask('x')]);
        final repository = RetryingTaskRepository(
          api,
          initialDelay: const Duration(milliseconds: 100),
        );
        List<String>? ids() {
          List<String>? result;
          api.loadAll().then((tasks) => result = [for (final t in tasks) t.id]);
          async.flushMicrotasks();
          return result;
        }

        api.failNext();
        var saved = false;
        repository
            .upsertAll([contractTask('a'), contractTask('b')])
            .then((_) => saved = true);
        async.elapse(const Duration(milliseconds: 100));
        expect(saved, isTrue);
        expect(ids(), ['x', 'a', 'b']);

        api.failNext();
        var deleted = false;
        repository.deleteAll(['x', 'a']).then((_) => deleted = true);
        async.elapse(const Duration(milliseconds: 100));
        expect(deleted, isTrue);
        expect(ids(), ['b']);
      });
    });

    test('loadAll và delete cũng được thử lại', () {
      fakeAsync((async) {
        final api = InMemoryTaskRepository(
          initial: [contractTask('a'), contractTask('b')],
        );
        final repository = RetryingTaskRepository(
          api,
          initialDelay: const Duration(milliseconds: 100),
        );

        api.failNext();
        List<String>? ids;
        repository.loadAll().then(
          (tasks) => ids = [for (final t in tasks) t.id],
        );
        async.elapse(const Duration(milliseconds: 100));
        expect(ids, ['a', 'b']);

        api.failNext();
        var deleted = false;
        repository.delete('a').then((_) => deleted = true);
        async.elapse(const Duration(milliseconds: 100));
        expect(deleted, isTrue);
      });
    });

    test('maxAttempts = 1 nghĩa là không thử lại', () {
      fakeAsync((async) {
        final api = InMemoryTaskRepository()..failNext();
        final retries = <int>[];
        final repository = RetryingTaskRepository(
          api,
          maxAttempts: 1,
          onRetry: (attempt, _) => retries.add(attempt),
        );

        Object? error;
        repository
            .upsert(contractTask('a'))
            .catchError((Object e) => error = e);
        async.flushMicrotasks();

        expect(error, isA<StorageException>());
        expect(retries, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('không thử lại lỗi không phải StorageException', () async {
      final broken = _BrokenRepository();
      final repository = RetryingTaskRepository(
        broken,
        initialDelay: Duration.zero,
      );

      await expectLater(
        repository.upsert(contractTask('a')),
        throwsA(isA<StateError>()),
      );
      expect(broken.calls, 1);
    });
  });
}
