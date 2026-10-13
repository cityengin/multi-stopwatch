import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/lap.dart';
import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/models/task_status.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';

final _createdAt = DateTime.utc(2026, 1, 1);

StopwatchTask _task(String id, {String? name}) => StopwatchTask(
  id: id,
  name: name ?? id,
  colorValue: 0xFF000000,
  createdAt: _createdAt,
);

void main() {
  group('InMemoryTaskRepository', () {
    test('mới tạo thì rỗng; initial được nạp sẵn theo thứ tự', () async {
      expect(await InMemoryTaskRepository().loadAll(), isEmpty);

      final repository = InMemoryTaskRepository([_task('a'), _task('b')]);
      expect((await repository.loadAll()).map((t) => t.id), ['a', 'b']);
    });

    test(
      'upsert: đồng hồ mới thêm vào cuối, ghi đè giữ nguyên vị trí',
      () async {
        final repository = InMemoryTaskRepository();
        await repository.upsert(_task('a'));
        await repository.upsert(_task('b'));
        await repository.upsert(_task('a', name: 'A mới'));

        final tasks = await repository.loadAll();
        expect(tasks.map((t) => t.id), ['a', 'b']);
        expect(tasks.first.name, 'A mới');
      },
    );

    test('delete: xóa theo id, id không tồn tại thì không lỗi', () async {
      final repository = InMemoryTaskRepository([_task('a'), _task('b')]);
      await repository.delete('a');
      await repository.delete('a');
      await repository.delete('khong-co');

      expect((await repository.loadAll()).map((t) => t.id), ['b']);
    });

    test(
      'đi qua JSON: đồng hồ đang chạy có lap được lưu và đọc lại y hệt',
      () async {
        final task = StopwatchTask(
          id: 'run',
          name: 'Chạy bộ',
          colorValue: 0xFF2196F3,
          createdAt: _createdAt,
          status: TaskStatus.running,
          accumulated: const Duration(seconds: 3),
          runningSince: _createdAt.add(const Duration(minutes: 1)),
          laps: [
            Lap(
              number: 1,
              split: const Duration(seconds: 1),
              total: const Duration(seconds: 1),
              recordedAt: _createdAt,
            ),
            Lap(
              number: 2,
              split: const Duration(seconds: 2),
              total: const Duration(seconds: 3),
              delta: const Duration(seconds: 1),
              recordedAt: _createdAt,
            ),
          ],
        );
        final repository = InMemoryTaskRepository();
        await repository.upsert(task);

        final loaded = (await repository.loadAll()).single;
        expect(loaded, task);
        expect(identical(loaded, task), isFalse);
      },
    );
  });
}
