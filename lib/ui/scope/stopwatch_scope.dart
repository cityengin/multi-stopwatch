import 'package:flutter/widgets.dart';

import '../../core/debug/stream_tracker.dart';
import '../../core/services/stopwatch_service.dart';

/// [InheritedWidget] cung cấp [StopwatchService] và [StreamTracker] xuống cây widget.
///
/// Giúp mọi widget con ở bất kỳ độ sâu nào (như `HomeScreen`, `TaskCard`,
/// `ElapsedText`, `DebugScreen`...) đều có thể lấy service và tracker thông qua
/// `StopwatchScope.of(context)` / `StopwatchScope.trackerOf(context)` gọn gàng,
/// đúng chuẩn Flutter, không phụ thuộc package state management bên ngoài.
class StopwatchScope extends InheritedWidget {
  const StopwatchScope({
    super.key,
    required this.service,
    this.tracker,
    required super.child,
  });

  /// Instance của [StopwatchService] dùng chung.
  final StopwatchService service;

  /// Bộ theo dõi subscription [StreamTracker] dùng cho màn Debug (nếu có).
  final StreamTracker? tracker;

  /// Lấy [StopwatchService] từ context gần nhất. Ném [StateError] nếu không tìm thấy.
  static StopwatchService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StopwatchScope>();
    if (scope == null) {
      throw StateError(
        'Không tìm thấy StopwatchScope trong widget tree. '
        'Hãy đảm bảo widget được bọc trong StopwatchScope.',
      );
    }
    return scope.service;
  }

  /// Lấy [StopwatchService] hoặc null nếu không tìm thấy trong context.
  static StopwatchService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StopwatchScope>()
        ?.service;
  }

  /// Lấy [StreamTracker] hoặc null nếu không tìm thấy trong context.
  static StreamTracker? trackerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StopwatchScope>()
        ?.tracker;
  }

  @override
  bool updateShouldNotify(StopwatchScope oldWidget) =>
      service != oldWidget.service || tracker != oldWidget.tracker;
}
