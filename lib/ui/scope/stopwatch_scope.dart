import 'package:flutter/widgets.dart';

import '../../core/services/stopwatch_service.dart';

/// [InheritedWidget] cung cấp [StopwatchService] xuống cây widget.
///
/// Giúp mọi widget con ở bất kỳ độ sâu nào (như `HomeScreen`, `TaskCard`,
/// `ElapsedText`, dialogs...) đều có thể lấy service thông qua
/// `StopwatchScope.of(context)` gọn gàng, đúng chuẩn Flutter, không phụ thuộc
/// package state management bên ngoài và không phải truyền qua nhiều tầng constructor.
class StopwatchScope extends InheritedWidget {
  const StopwatchScope({
    super.key,
    required this.service,
    required super.child,
  });

  /// Instance của [StopwatchService] dùng chung.
  final StopwatchService service;

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
    return context.dependOnInheritedWidgetOfExactType<StopwatchScope>()?.service;
  }

  @override
  bool updateShouldNotify(StopwatchScope oldWidget) =>
      service != oldWidget.service;
}
