import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/lap.dart';
import 'package:multi_stopwatch/core/models/stopwatch_task.dart';
import 'package:multi_stopwatch/core/models/task_snapshot.dart';
import 'package:multi_stopwatch/core/models/task_status.dart';

final _localStart = DateTime(2026, 10, 13, 22, 0, 0, 123, 456);

Map<String, dynamic> _viaJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

Lap _lap(int number, {Duration? delta}) => Lap(
  number: number,
  split: const Duration(seconds: 5, microseconds: 7),
  total: Duration(seconds: 5 * number, microseconds: 7),
  delta: delta,
  recordedAt: _localStart,
);

StopwatchTask _running() => StopwatchTask(
  id: 't1',
  name: 'Chạy bộ',
  colorValue: 0xFF2196F3,
  createdAt: _localStart,
  status: TaskStatus.running,
  accumulated: const Duration(seconds: 10),
  runningSince: _localStart,
  laps: [
    _lap(1),
    _lap(2, delta: Duration.zero),
  ],
);

void main() {
  group('Lap', () {
    test('JSON round-trip giữ nguyên (cả có và không có delta), == và '
        'hashCode khớp', () {
      for (final lap in [
        _lap(1),
        _lap(2, delta: const Duration(seconds: -1)),
      ]) {
        final decoded = Lap.fromJson(_viaJson(lap.toJson()));
        expect(decoded, lap);
        expect(decoded.hashCode, lap.hashCode);
      }
    });

    test('recordedAt được chuẩn hóa về UTC', () {
      expect(_lap(1).recordedAt.isUtc, isTrue);
      expect(_lap(1).recordedAt.isAtSameMomentAs(_localStart), isTrue);
    });

    test('copyWith đổi đúng trường được truyền', () {
      final lap = _lap(2, delta: Duration.zero);
      final changed = lap.copyWith(
        number: 3,
        split: Duration.zero,
        total: const Duration(seconds: 1),
        delta: const Duration(seconds: 2),
        recordedAt: DateTime.utc(2030),
      );

      expect(changed.number, 3);
      expect(changed.split, Duration.zero);
      expect(changed.total, const Duration(seconds: 1));
      expect(changed.delta, const Duration(seconds: 2));
      expect(changed.recordedAt, DateTime.utc(2030));
      expect(lap.copyWith(), lap);
      expect(changed, isNot(lap));
    });

    test('toString có số thứ tự, split, total, delta', () {
      expect(
        _lap(2, delta: Duration.zero).toString(),
        allOf(contains('#2'), contains('split'), contains('delta')),
      );
    });
  });

  group('StopwatchTask', () {
    test('JSON round-trip giữ nguyên; == và hashCode khớp', () {
      final task = _running();
      final decoded = StopwatchTask.fromJson(_viaJson(task.toJson()));

      expect(decoded, task);
      expect(decoded.hashCode, task.hashCode);
      expect(StopwatchTask.fromJson(task.toJson()), task);
    });

    test('elapsedAt = accumulated + đoạn đang chạy; giờ lùi thì kẹp về '
        'accumulated; đang pause thì cố định', () {
      final task = _running();
      final later = _localStart.add(const Duration(seconds: 3));

      expect(task.elapsedAt(later), const Duration(seconds: 13));
      expect(
        task.elapsedAt(_localStart.subtract(const Duration(hours: 1))),
        const Duration(seconds: 10),
      );
      final paused = task.copyWith(
        status: TaskStatus.paused,
        accumulated: task.elapsedAt(later),
        clearRunningSince: true,
      );
      expect(paused.runningSince, isNull);
      expect(
        paused.elapsedAt(later.add(const Duration(days: 1))),
        const Duration(seconds: 13),
      );
    });

    test('copyWith giữ id/createdAt; laps không sửa được và là bản copy', () {
      final source = [_lap(1)];
      final task = StopwatchTask(
        id: 't2',
        name: 'x',
        colorValue: 0,
        createdAt: _localStart,
        status: TaskStatus.paused,
        accumulated: const Duration(seconds: 5),
        laps: source,
      );
      source.clear();
      final renamed = task.copyWith(name: 'y', colorValue: 1);

      expect(task.laps, hasLength(1));
      expect(() => task.laps.add(task.laps.first), throwsUnsupportedError);
      expect(renamed.id, task.id);
      expect(renamed.createdAt, task.createdAt);
      expect(renamed.name, 'y');
      expect(renamed, isNot(task));
      expect(task.createdAt.isUtc, isTrue);
    });

    test('assert chặn trạng thái sai', () {
      expect(
        () => StopwatchTask(
          id: 'x',
          name: 'x',
          colorValue: 0,
          createdAt: _localStart,
          status: TaskStatus.running,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => StopwatchTask(
          id: 'x',
          name: 'x',
          colorValue: 0,
          createdAt: _localStart,
          accumulated: const Duration(seconds: 1),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _running().copyWith(
          runningSince: _localStart,
          clearRunningSince: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromJson báo FormatException khi dữ liệu hỏng', () {
      Map<String, dynamic> corrupt(void Function(Map<String, dynamic>) edit) {
        final json = _running().toJson();
        edit(json);
        return json;
      }

      final cases = <String, Map<String, dynamic>>{
        'sai kiểu': corrupt((json) => json['colorValue'] = 'đỏ'),
        'thiếu trường': corrupt((json) => json.remove('name')),
        'enum lạ': corrupt((json) => json['status'] = 'bay'),
        'ngày sai': corrupt((json) => json['createdAt'] = 'hôm qua'),
        'lap không phải object': corrupt((json) => json['laps'] = [1]),
        'laps không phải list': corrupt((json) => json['laps'] = 'không'),
      };
      cases.forEach((reason, json) {
        expect(
          () => StopwatchTask.fromJson(json),
          throwsFormatException,
          reason: reason,
        );
      });
    });

    test('toString có id, tên, trạng thái và số lap', () {
      expect(
        _running().toString(),
        allOf(contains('t1'), contains('Chạy bộ'), contains('running')),
      );
    });
  });

  group('TaskSnapshot', () {
    test('fromTask chụp elapsed tại thời điểm chỉ định', () {
      final task = _running();
      final snapshot = TaskSnapshot.fromTask(
        task,
        _localStart.add(const Duration(seconds: 3)),
      );

      expect(snapshot.id, task.id);
      expect(snapshot.name, task.name);
      expect(snapshot.colorValue, task.colorValue);
      expect(snapshot.createdAt, task.createdAt);
      expect(snapshot.status, TaskStatus.running);
      expect(snapshot.elapsed, const Duration(seconds: 13));
      expect(snapshot.laps, task.laps);
    });

    test('JSON round-trip giữ nguyên; == và hashCode khớp', () {
      final snapshot = TaskSnapshot.fromTask(_running(), _localStart);
      final decoded = TaskSnapshot.fromJson(_viaJson(snapshot.toJson()));

      expect(decoded, snapshot);
      expect(decoded.hashCode, snapshot.hashCode);
    });

    test('copyWith đổi đúng trường được truyền, giữ id/createdAt', () {
      final snapshot = TaskSnapshot.fromTask(_running(), _localStart);
      final changed = snapshot.copyWith(
        name: 'khác',
        colorValue: 1,
        status: TaskStatus.paused,
        elapsed: Duration.zero,
        laps: const [],
      );

      expect(changed.id, snapshot.id);
      expect(changed.createdAt, snapshot.createdAt);
      expect(changed.name, 'khác');
      expect(changed.colorValue, 1);
      expect(changed.status, TaskStatus.paused);
      expect(changed.elapsed, Duration.zero);
      expect(changed.laps, isEmpty);
      expect(snapshot.copyWith(), snapshot);
      expect(changed, isNot(snapshot));
    });

    test('fromJson báo FormatException khi dữ liệu hỏng', () {
      final json = TaskSnapshot.fromTask(_running(), _localStart).toJson()
        ..['elapsed'] = 1.5;

      expect(() => TaskSnapshot.fromJson(json), throwsFormatException);
    });

    test('toString có id, trạng thái và elapsed', () {
      expect(
        TaskSnapshot.fromTask(_running(), _localStart).toString(),
        allOf(contains('t1'), contains('running'), contains('elapsed')),
      );
    });
  });
}
