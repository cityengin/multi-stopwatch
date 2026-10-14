import 'package:flutter/material.dart';

import '../../core/services/stopwatch_service.dart';
import '../../core/transformers/rate_limit.dart';
import '../scope/stopwatch_scope.dart';
import '../utils/time_formatters.dart';

/// Widget chuyên trách hiển thị thời gian chạy dạng `mm:ss.cs`
/// (hoặc `hh:mm:ss.cs` khi đạt từ 1 giờ trở lên).
///
/// Thiết kế & Vòng đời Stream:
/// - Tách riêng widget này để chỉ cô lập việc rebuild ở đúng ô thời gian,
///   không gây rebuild thẻ cha (`TaskCard`) hay danh sách (`HomeScreen`).
/// - Lấy stream duy nhất một lần trước khi `build()` (trong `initState` nếu
///   nhận service từ constructor, hoặc trong `didChangeDependencies` nếu lấy qua
///   `StopwatchScope`). Tuyệt đối không tạo hay lấy stream trong hàm `build()`.
/// - Hỗ trợ [throttleDuration] thông qua `.throttled(..., trailing: true)` của core
///   để giảm số frame vẽ khi nhiều đồng hồ cùng chạy, đảm bảo app luôn mượt mà.
class ElapsedText extends StatefulWidget {
  const ElapsedText({
    super.key,
    required this.taskId,
    required this.initialElapsed,
    this.service,
    this.throttleDuration,
    this.style,
  });

  /// ID của đồng hồ cần hiển thị thời gian.
  final String taskId;

  /// Giá trị thời gian ban đầu để hiển thị ngay frame đầu tiên không bị nhấp nháy.
  final Duration initialElapsed;

  /// Service tùy chọn; nếu bỏ trống sẽ tự tìm trong [StopwatchScope].
  final StopwatchService? service;

  /// Thời gian throttle (ví dụ 33ms hoặc 50ms) để giới hạn tần suất vẽ lại UI.
  final Duration? throttleDuration;

  /// Kiểu chữ hiển thị (mặc định sử dụng font monospace để số không bị giật).
  final TextStyle? style;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Stream<Duration>? _elapsedStream;
  StopwatchService? _cachedService;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _cachedService = widget.service;
      _initStream(_cachedService!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_elapsedStream == null) {
      _cachedService = widget.service ?? StopwatchScope.of(context);
      _initStream(_cachedService!);
    }
  }

  @override
  void didUpdateWidget(covariant ElapsedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi đổi taskId hoặc đổi service, cần tạo lại stream tương ứng
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.service != widget.service ||
        oldWidget.throttleDuration != widget.throttleDuration) {
      final service =
          widget.service ?? _cachedService ?? StopwatchScope.of(context);
      _initStream(service);
    }
  }

  void _initStream(StopwatchService service) {
    var stream = service.elapsedStream(widget.taskId);
    if (widget.throttleDuration != null) {
      // trailing: true để đảm bảo không bị mất frame cuối cùng khi pause/reset
      stream = stream.throttled(widget.throttleDuration!, trailing: true);
    }
    _elapsedStream = stream;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return StreamBuilder<Duration>(
      stream: _elapsedStream,
      initialData: widget.initialElapsed,
      builder: (context, snapshot) {
        // Kiểm tra snapshot.hasError theo quy tắc 9
        if (snapshot.hasError) {
          return Text(
            '--:--.--',
            style: (widget.style ?? defaultStyle).copyWith(color: Colors.red),
          );
        }

        final elapsed = snapshot.data ?? widget.initialElapsed;
        return Text(
          formatElapsed(elapsed),
          style: widget.style ?? defaultStyle,
        );
      },
    );
  }
}
