import 'package:flutter/material.dart';

import '../../core/services/stopwatch_service.dart';
import '../scope/stopwatch_scope.dart';
import '../widgets/task_card.dart';

/// Màn hình danh sách các đồng hồ bấm giờ song song.
///
/// Quản lý vòng đời stream: lấy [tasksStream] một lần duy nhất trước khi [build]
/// (trong [initState] nếu truyền qua constructor, hoặc trong [didChangeDependencies]
/// nếu lấy từ [StopwatchScope]) để tránh tạo lại stream khi rebuild.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.service});

  /// [StopwatchService] tùy chọn; nếu không truyền thì sẽ lấy từ [StopwatchScope.of].
  final StopwatchService? service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<List<TaskSnapshot>>? _tasksStream;
  StopwatchService? _cachedService;

  StopwatchService get _service => _cachedService!;

  static const List<Color> _presetColors = [
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Orange
    Color(0xFF8E24AA), // Purple
    Color(0xFFE53935), // Red
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFDD835), // Yellow
    Color(0xFF3949AB), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    // Nếu service được truyền qua constructor, lấy stream ngay trong initState.
    if (widget.service != null) {
      _cachedService = widget.service;
      _tasksStream = _cachedService!.tasksStream;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nếu chưa có stream (dùng StopwatchScope), lấy từ InheritedWidget tại đây
    // vì initState không cho phép gọi dependOnInheritedWidgetOfExactType.
    if (_tasksStream == null) {
      _cachedService = widget.service ?? StopwatchScope.of(context);
      _tasksStream = _cachedService!.tasksStream;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _handleStart(String taskId) async {
    try {
      await _service.start(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Đồng hồ không còn tồn tại',
        InvalidTransitionException(:final action) => 'Không thể $action lúc này',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handlePause(String taskId) async {
    try {
      await _service.pause(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Đồng hồ không còn tồn tại',
        InvalidTransitionException(:final action) => 'Không thể $action lúc này',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _handleResume(String taskId) async {
    try {
      await _service.resume(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Đồng hồ không còn tồn tại',
        InvalidTransitionException(:final action) => 'Không thể $action lúc này',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Lỗi lưu trữ, đã hoàn tác');
    }
  }

  Future<void> _showCreateTaskDialog() async {
    final nameController = TextEditingController();
    Color selectedColor = _presetColors.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm đồng hồ mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Tên đồng hồ',
                        hintText: 'Ví dụ: Nấu ăn, Chạy bộ...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chọn màu đại diện:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((color) {
                        final isSelected = color == selectedColor;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = color),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.white,
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withAlpha(128),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Tạo'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final name = nameController.text.trim();
      try {
        await _service.createTask(
          name: name,
          colorValue: selectedColor.toARGB32(),
        );
      } on ArgumentError catch (e) {
        _showErrorSnackBar(e.message.toString());
      } on StorageException {
        _showErrorSnackBar('Lỗi khi lưu đồng hồ');
      }
    }
  }

  Future<void> _showRenameDialog(TaskSnapshot task) async {
    final controller = TextEditingController(text: task.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên đồng hồ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên mới',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newName = controller.text.trim();
      try {
        await _service.renameTask(task.id, newName);
      } on ArgumentError catch (e) {
        _showErrorSnackBar(e.message.toString());
      } on StopwatchException {
        _showErrorSnackBar('Đồng hồ không còn tồn tại');
      } on StorageException {
        _showErrorSnackBar('Lỗi khi lưu tên mới');
      }
    }
  }

  Future<void> _showChangeColorDialog(TaskSnapshot task) async {
    Color selectedColor = Color(task.colorValue);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi màu đồng hồ'),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = color.toARGB32() == selectedColor.toARGB32();
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.white,
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(128),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _service.changeTaskColor(
          task.id,
          selectedColor.toARGB32(),
        );
      } on StopwatchException {
        _showErrorSnackBar('Đồng hồ không còn tồn tại');
      } on StorageException {
        _showErrorSnackBar('Lỗi khi lưu màu mới');
      }
    }
  }

  Future<void> _confirmDelete(TaskSnapshot task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa đồng hồ "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _service.deleteTask(task.id);
      } on StorageException {
        _showErrorSnackBar('Lỗi khi xóa đồng hồ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Stopwatch'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<TaskSnapshot>>(
        stream: _tasksStream,
        initialData: _service.currentTasks,
        builder: (context, snapshot) {
          // Xử lý lỗi stream theo quy tắc 9
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text('Đã xảy ra lỗi: ${snapshot.error}'),
                ],
              ),
            );
          }

          final tasks = snapshot.data ?? const <TaskSnapshot>[];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có đồng hồ nào',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bấm nút + bên dưới để tạo đồng hồ đầu tiên',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskCard(
                key: ValueKey(task.id),
                task: task,
                onStart: () => _handleStart(task.id),
                onPause: () => _handlePause(task.id),
                onResume: () => _handleResume(task.id),
                onRename: () => _showRenameDialog(task),
                onChangeColor: () => _showChangeColorDialog(task),
                onDelete: () => _confirmDelete(task),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_task_fab'),
        onPressed: _showCreateTaskDialog,
        tooltip: 'Thêm đồng hồ',
        child: const Icon(Icons.add),
      ),
    );
  }
}
