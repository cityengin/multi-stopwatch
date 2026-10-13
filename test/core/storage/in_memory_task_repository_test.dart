import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';

import '../support/task_repository_contract.dart';

void main() {
  runTaskRepositoryContract(() async => InMemoryTaskRepository());

  group('InMemoryTaskRepository giả lập API', () {
    test('initial được nạp sẵn theo thứ tự', () async {
      final repository = InMemoryTaskRepository(
        initial: [contractTask('a'), contractTask('b')],
      );

      expect((await repository.loadAll()).map((t) => t.id), ['a', 'b']);
    });

    test('mỗi lần gọi chờ đủ latency như một request mạng', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository(
          latency: const Duration(milliseconds: 300),
        );
        var saved = false;
        repository.upsert(contractTask('a')).then((_) => saved = true);
        async.elapse(const Duration(milliseconds: 299));
        expect(saved, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(saved, isTrue);

        List<Object>? loaded;
        repository.loadAll().then((tasks) => loaded = tasks);
        async.elapse(const Duration(milliseconds: 299));
        expect(loaded, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(loaded, hasLength(1));
      });
    });

    test('failNext: đúng số lần gọi kế tiếp lỗi, lỗi đến sau độ trễ và '
        'không làm đổi dữ liệu', () {
      fakeAsync((async) {
        final repository = InMemoryTaskRepository(
          initial: [contractTask('a')],
          latency: const Duration(milliseconds: 200),
        )..failNext(2);
        final errors = <(Object, int)>[];
        void record(Object error) =>
            errors.add((error, async.elapsed.inMilliseconds));

        repository.upsert(contractTask('b')).catchError(record);
        async.elapse(const Duration(milliseconds: 199));
        expect(errors, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        repository.delete('a').catchError(record);
        async.elapse(const Duration(milliseconds: 200));

        expect(errors.map((e) => e.$1), [
          isA<StorageException>(),
          isA<StorageException>(),
        ]);
        expect(errors.map((e) => e.$2), [200, 400]);
        List<String>? ids;
        repository.loadAll().then(
          (tasks) => ids = [for (final t in tasks) t.id],
        );
        async.elapse(const Duration(milliseconds: 200));
        expect(ids, ['a']);
      });
    });

    test('failureRate: 0 không bao giờ lỗi, 1 luôn lỗi', () async {
      final repository = InMemoryTaskRepository();
      for (var i = 0; i < 20; i++) {
        await repository.upsert(contractTask('$i'));
      }

      repository.failureRate = 1;
      for (var i = 0; i < 20; i++) {
        await expectLater(
          repository.upsert(contractTask('x$i')),
          throwsA(isA<StorageException>()),
        );
      }
      repository.failureRate = 0;
      expect(await repository.loadAll(), hasLength(20));
    });

    test('failureRate với seed cố định cho chuỗi lỗi lặp lại được', () async {
      Future<List<bool>> outcomes() async {
        final repository = InMemoryTaskRepository(
          failureRate: 0.3,
          random: Random(7),
        );
        final results = <bool>[];
        for (var i = 0; i < 100; i++) {
          try {
            await repository.upsert(contractTask('$i'));
            results.add(true);
          } on StorageException {
            results.add(false);
          }
        }
        return results;
      }

      final first = await outcomes();
      final second = await outcomes();
      final failures = first.where((ok) => !ok).length;

      expect(second, first);
      expect(failures, inInclusiveRange(15, 45));
    });
  });
}
