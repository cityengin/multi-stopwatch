import 'package:meta/meta.dart';

import 'model_helpers.dart';

/// Một lần bấm lap của đồng hồ.
///
/// Vì sao lưu cả [split] lẫn [total] dù suy ra được từ nhau: UI và thống kê
/// đọc thẳng mà không phải tính lại theo lap trước, và mỗi dòng JSON khi
/// export tự đủ nghĩa.
@immutable
class Lap {
  /// Mọi thời điểm được chuẩn hóa về UTC để so sánh `==` và JSON round-trip
  /// luôn khớp, bất kể nơi tạo truyền giờ local hay UTC.
  Lap({
    required this.number,
    required this.split,
    required this.total,
    required DateTime recordedAt,
  }) : assert(number >= 1, 'number bắt đầu từ 1'),
       assert(!split.isNegative && !total.isNegative, 'Duration không âm'),
       recordedAt = recordedAt.toUtc();

  /// Ném [FormatException] nếu dữ liệu sai kiểu hoặc thiếu trường.
  factory Lap.fromJson(Map<String, dynamic> json) => Lap(
    number: readField<int>(json, 'number'),
    split: readDuration(json, 'split'),
    total: readDuration(json, 'total'),
    recordedAt: readDateTime(json, 'recordedAt'),
  );

  /// Số thứ tự lap, bắt đầu từ 1.
  final int number;

  /// Thời gian từ lap trước (hoặc từ lúc bắt đầu, với lap đầu tiên).
  final Duration split;

  /// Tổng elapsed của đồng hồ tại thời điểm bấm lap.
  final Duration total;

  /// Thời điểm bấm lap (UTC).
  final DateTime recordedAt;

  Lap copyWith({
    int? number,
    Duration? split,
    Duration? total,
    DateTime? recordedAt,
  }) => Lap(
    number: number ?? this.number,
    split: split ?? this.split,
    total: total ?? this.total,
    recordedAt: recordedAt ?? this.recordedAt,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'split': split.inMicroseconds,
    'total': total.inMicroseconds,
    'recordedAt': recordedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Lap &&
      other.number == number &&
      other.split == split &&
      other.total == total &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(number, split, total, recordedAt);

  @override
  String toString() => 'Lap(#$number, split: $split, total: $total)';
}
