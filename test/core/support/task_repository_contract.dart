import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/lap.dart';
import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/models/task_status.dart';
import 'package:multi_stopwatch/core/storage/task_repository.dart';

final contractCreatedAt = DateTime.utc(2026, 1, 1);

StopwatchTask contractTask(String id, {String? name}) => StopwatchTask(
  id: id,
  name: name ?? id,
  colorValue: 0xFF000000,
  createdAt: contractCreatedAt,
);

/// Bộ test hợp đồng mà mọi [TaskRepository] phải qua.
///
/// Vì sao dùng chung một bộ: service nhận repository qua dependency injection,
/// nên bản giả lập API và bản lưu trên máy phải cư xử giống hệt nhau thì mới
/// thay thế được cho nhau.
void runTaskRepositoryContract(Future<TaskRepository> Function() create) {
  group('hợp đồng TaskRepository', () {
    test('chưa lưu gì thì loadAll trả list rỗng', () async {
      expect(await (await create()).loadAll(), isEmpty);
    });

    test(
      'upsert: đồng hồ mới thêm vào cuối, ghi đè giữ nguyên vị trí',
      () async {
        final repository = await create();
        await repository.upsert(contractTask('a'));
        await repository.upsert(contractTask('b'));
        await repository.upsert(contractTask('a', name: 'A mới'));

        final tasks = await repository.loadAll();
        expect(tasks.map((t) => t.id), ['a', 'b']);
        expect(tasks.first.name, 'A mới');
      },
    );

    test(
      'delete: xóa theo id; xóa lại hoặc id không tồn tại thì không lỗi',
      () async {
        final repository = await create();
        await repository.upsert(contractTask('a'));
        await repository.upsert(contractTask('b'));
        await repository.delete('a');
        await repository.delete('a');
        await repository.delete('khong-co');

        expect((await repository.loadAll()).map((t) => t.id), ['b']);
      },
    );

    test('upsertAll: như upsert lần lượt — đồng hồ đã có giữ vị trí, đồng hồ '
        'mới thêm vào cuối theo thứ tự; lô rỗng không làm gì', () async {
      final repository = await create();
      await repository.upsert(contractTask('a'));
      await repository.upsert(contractTask('b'));
      await repository.upsertAll([
        contractTask('c'),
        contractTask('a', name: 'A mới'),
        contractTask('d'),
      ]);
      await repository.upsertAll(const []);

      final tasks = await repository.loadAll();
      expect(tasks.map((t) => t.id), ['a', 'b', 'c', 'd']);
      expect(tasks.first.name, 'A mới');
    });

    test('deleteAll: xóa các id được truyền, bỏ qua id không tồn tại; lô rỗng '
        'không làm gì', () async {
      final repository = await create();
      await repository.upsertAll([
        contractTask('a'),
        contractTask('b'),
        contractTask('c'),
      ]);
      await repository.deleteAll(['a', 'c', 'khong-co']);
      await repository.deleteAll(const []);

      expect((await repository.loadAll()).map((t) => t.id), ['b']);
      await repository.deleteAll(['b']);
      expect(await repository.loadAll(), isEmpty);
    });

    test('đồng hồ đang chạy có lap được lưu và đọc lại y hệt, '
        'là object mới', () async {
      final task = StopwatchTask(
        id: 'run',
        name: 'Chạy bộ',
        colorValue: 0xFF2196F3,
        createdAt: contractCreatedAt,
        status: TaskStatus.running,
        accumulated: const Duration(seconds: 3),
        runningSince: contractCreatedAt.add(const Duration(minutes: 1)),
        laps: [
          Lap(
            number: 1,
            split: const Duration(seconds: 1),
            total: const Duration(seconds: 1),
            recordedAt: contractCreatedAt,
          ),
          Lap(
            number: 2,
            split: const Duration(seconds: 2),
            total: const Duration(seconds: 3),
            delta: const Duration(seconds: 1),
            recordedAt: contractCreatedAt,
          ),
        ],
      );
      final repository = await create();
      await repository.upsert(task);

      final loaded = (await repository.loadAll()).single;
      expect(loaded, task);
      expect(identical(loaded, task), isFalse);
    });
  });
}
