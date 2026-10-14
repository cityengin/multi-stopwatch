import 'package:flutter/material.dart';

import '../../core/services/stopwatch_service.dart';
import 'elapsed_text.dart';

/// Thẻ hiển thị một đồng hồ trong danh sách.
///
/// Tách thành widget riêng để cô lập layout và tương tác của từng item.
/// Thời gian chạy được giao cho [ElapsedText] render độc lập để tránh rebuild thẻ.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.service,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
    this.onTap,
    this.margin,
  });

  final TaskSnapshot task;
  final StopwatchService? service;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskColor = Color(task.colorValue);

    final (statusLabel, statusColor) = switch (task.status) {
      TaskStatus.idle => ('Sẵn sàng', Colors.grey),
      TaskStatus.running => ('Đang chạy', Colors.green),
      TaskStatus.paused => ('Tạm dừng', Colors.orange),
    };

    return Card(
      elevation: 2,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: taskColor.withAlpha(120), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Vòng tròn màu nhận diện của đồng hồ
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: taskColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Badge trạng thái
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Menu các thao tác thêm
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Tùy chọn',
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                        case 'color':
                          onChangeColor();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Đổi tên'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'color',
                        child: Row(
                          children: [
                            Icon(Icons.palette, size: 20),
                            SizedBox(width: 8),
                            Text('Đổi màu'),
                          ],
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Xóa', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Hiển thị thời gian chạy mm:ss.cs qua ElapsedText
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  ElapsedText(
                    taskId: task.id,
                    initialElapsed: task.elapsed,
                    service: service,
                    throttleDuration: const Duration(milliseconds: 33),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                      color: task.status == TaskStatus.running
                          ? taskColor
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 16),
              // Hàng nút điều khiển start / pause nhanh
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (task.status == TaskStatus.idle)
                    FilledButton.icon(
                      key: Key('start_btn_${task.id}'),
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Bắt đầu'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                    ),
                  if (task.status == TaskStatus.running)
                    FilledButton.icon(
                      key: Key('pause_btn_${task.id}'),
                      onPressed: onPause,
                      icon: const Icon(Icons.pause),
                      label: const Text('Tạm dừng'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                      ),
                    ),
                  if (task.status == TaskStatus.paused)
                    FilledButton.icon(
                      key: Key('resume_btn_${task.id}'),
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Tiếp tục'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
