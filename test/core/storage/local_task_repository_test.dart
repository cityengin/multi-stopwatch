import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/services/stopwatch_manager.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';
import 'package:multi_stopwatch/core/storage/local_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_time_sources.dart';
import '../support/task_repository_contract.dart';

Future<LocalTaskRepository> _repository({
  String key = LocalTaskRepository.defaultKey,
}) async =>
    LocalTaskRepository(await SharedPreferences.getInstance(), key: key);

/// Giả lập khởi động lại app: bỏ instance cũ, đọc lại từ bộ nhớ máy.
Future<LocalTaskRepository> _repositoryAfterRestart() async {
  SharedPreferences.resetStatic();
  return _repository();
}

/// [SharedPreferences] giả có lệnh ghi thất bại theo [write], để thử các nhánh
/// lỗi mà bản giả của package không tạo ra được.
class _FailingPreferences implements SharedPreferences {
  _FailingPreferences(this.write);

  final Future<bool> Function() write;

  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) => write();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  runTaskRepositoryContract(_repository);

  group('LocalTaskRepository', () {
    test(
      'ghi thất bại (setString trả false hoặc ném lỗi) báo StorageException',
      () async {
        final rejected = LocalTaskRepository(
          _FailingPreferences(() async => false),
        );
        final crashed = LocalTaskRepository(
          _FailingPreferences(() async => throw Exception('đĩa đầy')),
        );

        await expectLater(
          rejected.upsert(contractTask('a')),
          throwsA(
            isA<StorageException>().having((e) => e.cause, 'cause', isNull),
          ),
        );
        await expectLater(
          crashed.upsert(contractTask('a')),
          throwsA(
            isA<StorageException>().having(
              (e) => e.cause,
              'cause',
              isA<Exception>(),
            ),
          ),
        );
      },
    );

    test('lưu thành JSON có version dưới một key duy nhất', () async {
      final repository = await _repository();
      await repository.upsert(contractTask('a'));
      await repository.upsert(contractTask('b'));

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {LocalTaskRepository.defaultKey});
      final stored = jsonDecode(
        preferences.getString(LocalTaskRepository.defaultKey)!,
      ) as Map<String, dynamic>;
      expect(stored['version'], LocalTaskRepository.schemaVersion);
      expect((stored['tasks'] as List<dynamic>).map((t) => t['id']), [
        'a',
        'b',
      ]);
    });

    test('dữ liệu còn nguyên sau khi khởi động lại app', () async {
      await (await _repository()).upsert(contractTask('a', name: 'Đã lưu'));

      final tasks = await (await _repositoryAfterRestart()).loadAll();
      expect(tasks.single.name, 'Đã lưu');
    });

    test('key khác nhau thì dữ liệu tách biệt', () async {
      await (await _repository(key: 'ho-so-1')).upsert(contractTask('a'));
      await (await _repository(key: 'ho-so-2')).upsert(contractTask('b'));

      expect(
        (await (await _repository(key: 'ho-so-1')).loadAll()).single.id,
        'a',
      );
      expect(
        (await (await _repository(key: 'ho-so-2')).loadAll()).single.id,
        'b',
      );
    });

    test('gọi chồng nhau không chờ nhau vẫn không mất dữ liệu', () async {
      final repository = await _repository();
      await Future.wait([
        repository.upsert(contractTask('a')),
        repository.upsert(contractTask('b')),
        repository.upsert(contractTask('c')),
        repository.delete('b'),
      ]);

      final tasks = await (await _repositoryAfterRestart()).loadAll();
      expect(tasks.map((t) => t.id), ['a', 'c']);
    });

    test('dữ liệu hỏng báo StorageException kèm nguyên nhân, '
        'và không bị ghi đè mất', () async {
      const corrupted = [
        'không phải json',
        '[]',
        '{"version": 99, "tasks": []}',
        '{"version": 1, "tasks": {}}',
        '{"version": 1, "tasks": [1]}',
        '{"version": 1, "tasks": [{"id": 1}]}',
      ];
      for (final raw in corrupted) {
        SharedPreferences.setMockInitialValues({
          LocalTaskRepository.defaultKey: raw,
        });
        final repository = await _repository();

        await expectLater(
          repository.loadAll(),
          throwsA(
            isA<StorageException>().having(
              (e) => e.cause,
              'cause',
              isA<FormatException>(),
            ),
          ),
          reason: raw,
        );
        await expectLater(
          repository.upsert(contractTask('a')),
          throwsA(isA<StorageException>()),
          reason: raw,
        );
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(LocalTaskRepository.defaultKey),
          raw,
          reason: raw,
        );
      }
    });

    test('restart giả lập với StopwatchManager: danh sách, lap và đồng hồ '
        'đang chạy được khôi phục đúng thời gian', () async {
      final time = ManualTimeSource();
      final first = await StopwatchManager.open(
        repository: await _repository(),
        timeSource: time,
      );
      final run = (await first.createTask(name: 'Chạy bộ', colorValue: 1)).id;
      final paused = (await first.createTask(name: 'Đọc', colorValue: 2)).id;
      await first.start(run);
      await first.start(paused);
      time.advance(const Duration(seconds: 2));
      final lap = await first.lap(run);
      await first.pause(paused);
      time.advance(const Duration(seconds: 1));
      await first.dispose();

      time.advance(const Duration(minutes: 5));
      final second = await StopwatchManager.open(
        repository: await _repositoryAfterRestart(),
        timeSource: ManualTimeSource(wall: time.now()),
      );
      final restored = second.currentTasks;

      expect(restored.map((t) => t.id), [run, paused]);
      expect(restored[0].status, TaskStatus.running);
      expect(restored[0].elapsed, const Duration(minutes: 5, seconds: 3));
      expect(restored[0].laps, [lap]);
      expect(restored[1].status, TaskStatus.paused);
      expect(restored[1].elapsed, const Duration(seconds: 2));
      await second.dispose();
    });
  });
}
