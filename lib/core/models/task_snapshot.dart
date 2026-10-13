import 'package:meta/meta.dart';

import 'lap.dart';
import 'model_helpers.dart';
import 'stopwatch_task.dart';
import 'task_status.dart';

/// Ảnh chụp chỉ-đọc của một đồng hồ tại một thời điểm, đây là thứ UI nhận
/// qua Stream.
///
/// Vì sao tách khỏi [StopwatchTask]: UI chỉ cần biết "đang hiển thị bao
/// nhiêu", không cần biết elapsed được tính từ accumulated/runningSince ra
/// sao. Nếu implementation đổi cách lưu trữ thì UI không phải sửa.
@immutable
class TaskSnapshot {
  /// [laps] được copy thành list không sửa được; [createdAt] chuẩn hóa về UTC.
  TaskSnapshot({
    required this.id,
    required this.name,
    required this.colorValue,
    required DateTime createdAt,
    required this.status,
    required this.elapsed,
    List<Lap> laps = const [],
  }) : assert(!elapsed.isNegative, 'elapsed không âm'),
       createdAt = createdAt.toUtc(),
       laps = List.unmodifiable(laps);

  /// Chụp [task] tại thời điểm [now].
  factory TaskSnapshot.fromTask(StopwatchTask task, DateTime now) =>
      TaskSnapshot(
        id: task.id,
        name: task.name,
        colorValue: task.colorValue,
        createdAt: task.createdAt,
        status: task.status,
        elapsed: task.elapsedAt(now),
        laps: task.laps,
      );

  /// Ném [FormatException] nếu dữ liệu sai kiểu hoặc thiếu trường.
  factory TaskSnapshot.fromJson(Map<String, dynamic> json) => TaskSnapshot(
    id: readField<String>(json, 'id'),
    name: readField<String>(json, 'name'),
    colorValue: readField<int>(json, 'colorValue'),
    createdAt: readDateTime(json, 'createdAt'),
    status: readEnum(json, 'status', TaskStatus.values),
    elapsed: readDuration(json, 'elapsed'),
    laps: [for (final lap in readObjectList(json, 'laps')) Lap.fromJson(lap)],
  );

  final String id;

  final String name;

  /// Màu ARGB 32-bit; UI dùng `Color(colorValue)`.
  final int colorValue;

  /// Thời điểm tạo đồng hồ (UTC).
  final DateTime createdAt;

  final TaskStatus status;

  /// Elapsed tại lúc chụp. Đang chạy thì giá trị này cũ đi theo thời gian;
  /// muốn hiển thị liên tục thì dùng `StopwatchService.elapsedStream`.
  final Duration elapsed;

  /// Các lap theo thứ tự bấm (lap 1 đứng đầu).
  final List<Lap> laps;

  /// [id] và [createdAt] là danh tính của đồng hồ nên không có ở đây.
  TaskSnapshot copyWith({
    String? name,
    int? colorValue,
    TaskStatus? status,
    Duration? elapsed,
    List<Lap>? laps,
  }) => TaskSnapshot(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt,
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    laps: laps ?? this.laps,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'elapsed': elapsed.inMicroseconds,
    'laps': [for (final lap in laps) lap.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is TaskSnapshot &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.createdAt == createdAt &&
      other.status == status &&
      other.elapsed == elapsed &&
      listEquals(other.laps, laps);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    createdAt,
    status,
    elapsed,
    Object.hashAll(laps),
  );

  @override
  String toString() =>
      'TaskSnapshot($id, "$name", ${status.name}, elapsed: $elapsed, '
      'laps: ${laps.length})';
}
