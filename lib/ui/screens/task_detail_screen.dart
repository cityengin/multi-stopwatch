import 'package:flutter/material.dart';

import '../../core/services/stopwatch_service.dart';
import '../scope/stopwatch_scope.dart';
import '../utils/time_formatters.dart';
import '../widgets/elapsed_text.dart';

/// Màn hình chi tiết một đồng hồ bấm giờ.
///
/// Tính năng:
/// - Hiển thị số lớn dạng `mm:ss.cs` thông qua [ElapsedText] dùng [StreamBuilder].
/// - Các nút điều khiển Start, Pause, Resume, Reset và nút ghi Vòng (Lap).
/// - Bảng/danh sách các lap kèm thời gian vòng (split), tổng thời gian (total)
///   và độ chênh lệch so với vòng trước (delta: âm là nhanh hơn, dương là chậm hơn).
/// - Vòng đời: Khi rời màn hình (unmount), mọi subscription từ `StreamBuilder`
///   được hủy tự động và triệt để, không gây rò rỉ tài nguyên.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.initialTask,
    this.service,
  });

  final String taskId;
  final TaskSnapshot? initialTask;
  final StopwatchService? service;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Stream<TaskSnapshot?>? _taskStream;
  StopwatchService? _cachedService;

  StopwatchService get _service => _cachedService!;

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
    if (_taskStream == null) {
      _cachedService = widget.service ?? StopwatchScope.of(context);
      _initStream(_cachedService!);
    }
  }

  void _initStream(StopwatchService service) {
    // Lấy stream một lần duy nhất trước khi build, phát snapshot mới nhất của task này
    _taskStream = service.tasksStream.map((tasks) {
      final matches = tasks.where((t) => t.id == widget.taskId);
      return matches.isEmpty ? null : matches.first;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _handleStart() async {
    try {
      await _service.start(widget.taskId);
    } on StopwatchException catch (e) {
      _showErrorSnackBar(e.message);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handlePause() async {
    try {
      await _service.pause(widget.taskId);
    } on StopwatchException catch (e) {
      _showErrorSnackBar(e.message);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handleResume() async {
    try {
      await _service.resume(widget.taskId);
    } on StopwatchException catch (e) {
      _showErrorSnackBar(e.message);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handleReset() async {
    try {
      await _service.reset(widget.taskId);
    } on StopwatchException catch (e) {
      _showErrorSnackBar(e.message);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handleLap() async {
    try {
      await _service.lap(widget.taskId);
    } on StopwatchException catch (e) {
      _showErrorSnackBar(e.message);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  TaskSnapshot? _findInitialTask() {
    if (widget.initialTask != null) return widget.initialTask;
    final matches = _cachedService?.currentTasks.where(
      (t) => t.id == widget.taskId,
    );
    return (matches != null && matches.isNotEmpty) ? matches.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskSnapshot?>(
      stream: _taskStream,
      initialData: _findInitialTask(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chi tiết đồng hồ')),
            body: Center(
              child: Text(
                'Lỗi nạp đồng hồ: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final task = snapshot.data;
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chi tiết đồng hồ')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Đồng hồ này không còn tồn tại hoặc đã bị xóa.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final taskColor = Color(task.colorValue);
        final theme = Theme.of(context);

        final (statusLabel, statusColor) = switch (task.status) {
          TaskStatus.idle => ('Sẵn sàng', Colors.grey),
          TaskStatus.running => ('Đang chạy', Colors.green),
          TaskStatus.paused => ('Tạm dừng', Colors.orange),
        };

        // Xác định best lap và worst lap nếu có từ 2 lap trở lên
        Lap? bestLap;
        Lap? worstLap;
        if (task.laps.length >= 2) {
          bestLap = task.laps.reduce((a, b) => a.split < b.split ? a : b);
          worstLap = task.laps.reduce((a, b) => a.split > b.split ? a : b);
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: taskColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(task.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              const SizedBox(height: 16),
              // Badge trạng thái
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Ô số lớn hiển thị thời gian mm:ss.cs
              ElapsedText(
                taskId: task.id,
                initialElapsed: task.elapsed,
                service: _service,
                throttleDuration: const Duration(milliseconds: 33),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 2.0,
                  color: task.status == TaskStatus.running ? taskColor : null,
                ),
              ),
              const SizedBox(height: 24),
              // Hàng nút điều khiển Start/Pause/Resume, Lap, Reset
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Nút Reset
                    OutlinedButton.icon(
                      key: const Key('detail_reset_btn'),
                      onPressed: task.status != TaskStatus.idle
                          ? _handleReset
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Đặt lại'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                    // Nút Start / Pause / Resume
                    if (task.status == TaskStatus.idle)
                      FilledButton.icon(
                        key: const Key('detail_start_btn'),
                        onPressed: _handleStart,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Bắt đầu'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    if (task.status == TaskStatus.running)
                      FilledButton.icon(
                        key: const Key('detail_pause_btn'),
                        onPressed: _handlePause,
                        icon: const Icon(Icons.pause),
                        label: const Text('Tạm dừng'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    if (task.status == TaskStatus.paused)
                      FilledButton.icon(
                        key: const Key('detail_resume_btn'),
                        onPressed: _handleResume,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Tiếp tục'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    // Nút Lap
                    FilledButton.tonalIcon(
                      key: const Key('detail_lap_btn'),
                      onPressed: task.status == TaskStatus.running
                          ? _handleLap
                          : null,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Vòng'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              // Tiêu đề danh sách Lap
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách vòng (${task.laps.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (task.laps.isNotEmpty)
                      Text(
                        'Lap gần nhất ở đầu',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Danh sách Lap
              Expanded(
                child: task.laps.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa ghi nhận vòng nào.\nBấm "Vòng" khi đang chạy để ghi lại thời gian chặng.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: task.laps.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          // Hiển thị lap mới nhất ở trên cùng
                          final lap = task.laps[task.laps.length - 1 - index];
                          final isBest =
                              bestLap != null && lap.number == bestLap.number;
                          final isWorst =
                              worstLap != null && lap.number == worstLap.number;

                          Color deltaColor = Colors.grey.shade600;
                          if (lap.delta != null) {
                            if (lap.delta! < Duration.zero) {
                              deltaColor = Colors.green.shade700;
                            } else if (lap.delta! > Duration.zero) {
                              deltaColor = Colors.red.shade700;
                            }
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isBest
                                  ? Colors.green.shade100
                                  : isWorst
                                  ? Colors.red.shade100
                                  : Colors.grey.shade200,
                              child: Text(
                                '#${lap.number}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isBest
                                      ? Colors.green.shade800
                                      : isWorst
                                      ? Colors.red.shade800
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  formatElapsed(lap.split),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isBest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Nhanh nhất',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else if (isWorst) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      border: Border.all(
                                        color: Colors.red.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Chậm nhất',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'Tổng: ${formatElapsed(lap.total)}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            trailing: Text(
                              formatDelta(lap.delta),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: deltaColor,
                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
