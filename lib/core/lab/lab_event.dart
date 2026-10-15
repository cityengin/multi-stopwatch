import 'package:meta/meta.dart';

/// Hàng đợi mà đoạn code đang chạy được lấy ra từ đó.
enum LabQueue {
  /// Mã đồng bộ của lượt chạy hiện tại (call stack ban đầu).
  sync,

  /// Hàng đợi microtask: `scheduleMicrotask`, `Future.microtask`, `then` của
  /// Future đã hoàn thành, phần sau `await` một Future đã xong sẵn.
  microtask,

  /// Hàng đợi event: Timer, `Future()`, `Future.delayed`, I/O, sự kiện UI.
  event,
}

/// Một dòng kết quả của `EventLabRunner`: đoạn code nào chạy, chạy từ hàng
/// đợi nào, vào lúc nào.
@immutable
class LabEvent {
  const LabEvent({
    required this.sequence,
    required this.label,
    required this.queue,
    required this.at,
  });

  /// Thứ tự thực thi thực tế, bắt đầu từ 1.
  final int sequence;

  final String label;

  /// Hàng đợi mà đoạn code ghi sự kiện này đang chạy từ đó, do Zone phát hiện
  /// lúc chạy chứ không ghi tay.
  final LabQueue queue;

  /// Thời gian từ lúc kịch bản bắt đầu (đồng hồ đơn điệu).
  final Duration at;

  @override
  bool operator ==(Object other) =>
      other is LabEvent &&
      other.sequence == sequence &&
      other.label == label &&
      other.queue == queue &&
      other.at == at;

  @override
  int get hashCode => Object.hash(sequence, label, queue, at);

  @override
  String toString() => '#$sequence [${queue.name}] $label (+$at)';
}
