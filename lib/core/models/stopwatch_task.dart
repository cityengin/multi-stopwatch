import 'package:meta/meta.dart';

import 'lap.dart';
import 'model_helpers.dart';
import 'task_status.dart';

/// Trạng thái lưu trữ của một đồng hồ, đây là thứ được ghi xuống
/// `TaskRepository`.
///
/// Vì sao không lưu sẵn "elapsed": khi đang chạy, elapsed thay đổi liên tục.
/// Model chỉ lưu [accumulated] (tổng các đoạn chạy đã xong) và [runningSince]
/// (mốc bắt đầu đoạn đang chạy), rồi tính `elapsed = accumulated + (now -
/// runningSince)`. Nhờ vậy app bị tắt rồi mở lại vẫn ra đúng giờ, và không bị
/// trôi giờ như khi cộng dồn từng tick của Timer.
@immutable
class StopwatchTask {
  /// [laps] được copy thành list không sửa được, và mọi thời điểm được chuẩn
  /// hóa về UTC: bất biến thật sự, không chỉ "quy ước".
  StopwatchTask({
    required this.id,
    required this.name,
    required this.colorValue,
    required DateTime createdAt,
    this.status = TaskStatus.idle,
    this.accumulated = Duration.zero,
    DateTime? runningSince,
    List<Lap> laps = const [],
  }) : assert(
         colorValue >= 0 && colorValue <= 0xFFFFFFFF,
         'colorValue là ARGB 32-bit',
       ),
       assert(!accumulated.isNegative, 'accumulated không âm'),
       assert(
         (status == TaskStatus.running) == (runningSince != null),
         'runningSince khác null khi và chỉ khi đang running',
       ),
       assert(
         status != TaskStatus.idle ||
             (accumulated == Duration.zero && laps.isEmpty),
         'idle nghĩa là chưa có thời gian và lap',
       ),
       createdAt = createdAt.toUtc(),
       runningSince = runningSince?.toUtc(),
       laps = List.unmodifiable(laps);

  /// Ném [FormatException] nếu dữ liệu sai kiểu hoặc thiếu trường.
  factory StopwatchTask.fromJson(Map<String, dynamic> json) => StopwatchTask(
    id: readField<String>(json, 'id'),
    name: readField<String>(json, 'name'),
    colorValue: readField<int>(json, 'colorValue'),
    createdAt: readDateTime(json, 'createdAt'),
    status: readEnum(json, 'status', TaskStatus.values),
    accumulated: readDuration(json, 'accumulated'),
    runningSince: readNullableDateTime(json, 'runningSince'),
    laps: [for (final lap in readObjectList(json, 'laps')) Lap.fromJson(lap)],
  );

  /// Định danh duy nhất do service sinh ra, không bao giờ đổi.
  final String id;

  final String name;

  /// Màu dạng số ARGB 32-bit (vd 0xFF2196F3).
  ///
  /// Vì sao không dùng `Color`: core là Dart thuần, không phụ thuộc Flutter;
  /// UI tự chuyển bằng `Color(colorValue)`.
  final int colorValue;

  /// Thời điểm tạo (UTC).
  final DateTime createdAt;

  final TaskStatus status;

  /// Tổng thời gian của các đoạn chạy đã kết thúc (trước lần start/resume gần
  /// nhất).
  final Duration accumulated;

  /// Mốc bắt đầu đoạn đang chạy (UTC); khác null khi và chỉ khi [status] là
  /// [TaskStatus.running].
  final DateTime? runningSince;

  /// Các lap theo thứ tự bấm (lap 1 đứng đầu).
  final List<Lap> laps;

  /// Elapsed tại thời điểm [now].
  ///
  /// Nếu đồng hồ hệ thống bị chỉnh lùi khiến `now` sớm hơn [runningSince],
  /// đoạn đang chạy được tính là 0: elapsed không bao giờ nhỏ hơn
  /// [accumulated].
  Duration elapsedAt(DateTime now) {
    final since = runningSince;
    if (since == null) return accumulated;
    final segment = now.difference(since);
    return segment.isNegative ? accumulated : accumulated + segment;
  }

  /// [id] và [createdAt] là danh tính của đồng hồ nên không có ở đây.
  ///
  /// Vì sao có [clearRunningSince]: tham số `runningSince: null` không phân
  /// biệt được "giữ nguyên" với "xóa về null", nên khi pause/reset cần cờ
  /// riêng.
  StopwatchTask copyWith({
    String? name,
    int? colorValue,
    TaskStatus? status,
    Duration? accumulated,
    DateTime? runningSince,
    bool clearRunningSince = false,
    List<Lap>? laps,
  }) {
    assert(
      !(clearRunningSince && runningSince != null),
      'Không truyền đồng thời runningSince và clearRunningSince',
    );
    return StopwatchTask(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt,
      status: status ?? this.status,
      accumulated: accumulated ?? this.accumulated,
      runningSince: clearRunningSince
          ? null
          : (runningSince ?? this.runningSince),
      laps: laps ?? this.laps,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'accumulated': accumulated.inMicroseconds,
    'runningSince': runningSince?.toIso8601String(),
    'laps': [for (final lap in laps) lap.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is StopwatchTask &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.createdAt == createdAt &&
      other.status == status &&
      other.accumulated == accumulated &&
      other.runningSince == runningSince &&
      listEquals(other.laps, laps);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    createdAt,
    status,
    accumulated,
    runningSince,
    Object.hashAll(laps),
  );

  @override
  String toString() =>
      'StopwatchTask($id, "$name", ${status.name}, '
      'accumulated: $accumulated, laps: ${laps.length})';
}
