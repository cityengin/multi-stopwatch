import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/stopwatch_service.dart';
import '../../core/transformers/rate_limit.dart';
import '../scope/stopwatch_scope.dart';
import '../widgets/task_card.dart';
import 'debug_screen.dart';
import 'event_lab_screen.dart';
import 'task_detail_screen.dart';

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

  final TextEditingController _searchFieldController = TextEditingController();
  final StreamController<String> _searchController =
      StreamController<String>.broadcast();
  StreamSubscription<String>? _searchSubscription;
  String _searchQuery = '';

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

    // Lắng nghe text tìm kiếm qua debounce 300ms của core
    _searchSubscription = _searchController.stream
        .debounced(const Duration(milliseconds: 300))
        .listen((query) {
          if (mounted) {
            setState(() {
              _searchQuery = query;
            });
          }
        });
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _searchController.close();
    _searchFieldController.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
  }

  Future<void> _handleStart(String taskId) async {
    try {
      await _service.start(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Stopwatch no longer exists',
        InvalidTransitionException(:final action) =>
          'Cannot $action right now',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Storage error, reverted');
    }
  }

  Future<void> _handlePause(String taskId) async {
    try {
      await _service.pause(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Stopwatch no longer exists',
        InvalidTransitionException(:final action) =>
          'Cannot $action right now',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Storage error, reverted');
    }
  }

  Future<void> _handleResume(String taskId) async {
    try {
      await _service.resume(taskId);
    } on StopwatchException catch (error) {
      final msg = switch (error) {
        TaskNotFoundException() => 'Stopwatch no longer exists',
        InvalidTransitionException(:final action) =>
          'Cannot $action right now',
      };
      _showErrorSnackBar(msg);
    } on StorageException {
      _showErrorSnackBar('Storage error, reverted');
    }
  }

  Future<void> _handleRunAll() async {
    try {
      await _service.runAll();
    } on StorageException {
      _showErrorSnackBar('Storage error while running all');
    } catch (e) {
      _showErrorSnackBar('Cannot run all: $e');
    }
  }

  Future<void> _handlePauseAll() async {
    try {
      await _service.pauseAll();
    } on StorageException {
      _showErrorSnackBar('Storage error while pausing all');
    } catch (e) {
      _showErrorSnackBar('Cannot pause all: $e');
    }
  }

  Future<void> _confirmResetAll(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Reset All'),
        content: Text('Reset all $count stopwatches to 00:00 and clear all laps?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _service.resetAll();
      } on StorageException {
        _showErrorSnackBar('Storage error while resetting all');
      } catch (e) {
        _showErrorSnackBar('Cannot reset all: $e');
      }
    }
  }

  Future<void> _confirmDeleteAll(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete All'),
        content: Text(
          'Delete all $count stopwatches? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _service.deleteAll();
      } on StorageException {
        _showErrorSnackBar('Storage error while deleting all');
      } catch (e) {
        _showErrorSnackBar('Cannot delete all: $e');
      }
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
              title: const Text('Add New Stopwatch'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Stopwatch Name',
                        hintText: 'e.g., Cooking, Workout...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select color:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((color) {
                        final isSelected = color == selectedColor;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
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
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Create'),
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
        _showErrorSnackBar('Error saving stopwatch');
      }
    }
  }

  Future<void> _showRenameDialog(TaskSnapshot task) async {
    final controller = TextEditingController(text: task.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Stopwatch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Save'),
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
        _showErrorSnackBar('Stopwatch no longer exists');
      } on StorageException {
        _showErrorSnackBar('Error saving new name');
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
              title: const Text('Change Stopwatch Color'),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected =
                      color.toARGB32() == selectedColor.toARGB32();
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
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _service.changeTaskColor(task.id, selectedColor.toARGB32());
      } on StopwatchException {
        _showErrorSnackBar('Stopwatch no longer exists');
      } on StorageException {
        _showErrorSnackBar('Error saving new color');
      }
    }
  }

  Future<void> _confirmDelete(TaskSnapshot task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _service.deleteTask(task.id);
      } on StorageException {
        _showErrorSnackBar('Error deleting stopwatch');
      }
    }
  }

  void _navigateToDetail(TaskSnapshot task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          taskId: task.id,
          initialTask: task,
          service: _service,
        ),
      ),
    );
  }

  void _navigateToDebug() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const DebugScreen()));
  }

  void _navigateToLab() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const EventLabScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Stopwatch'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('home_lab_btn'),
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Event Loop Lab',
            onPressed: _navigateToLab,
          ),
          IconButton(
            key: const Key('home_debug_btn'),
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Stream Tracker (Debug)',
            onPressed: _navigateToDebug,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Ô tìm kiếm đồng hồ (sử dụng debounce 300ms của core)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('home_search_field'),
              controller: _searchFieldController,
              onChanged: (text) => _searchController.add(text),
              decoration: InputDecoration(
                hintText: 'Search stopwatches by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchFieldController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('home_search_clear_btn'),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchFieldController.clear();
                          _searchController.add('');
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // 2. Danh sách đồng hồ responsive qua LayoutBuilder
          Expanded(
            child: StreamBuilder<List<TaskSnapshot>>(
              stream: _tasksStream,
              initialData: _service.currentTasks,
              builder: (context, snapshot) {
                // Xử lý lỗi stream theo quy tắc 9
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text('An error occurred: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final tasks = snapshot.data ?? const <TaskSnapshot>[];
                final canRunAll = tasks.any(
                  (t) =>
                      t.status == TaskStatus.idle ||
                      t.status == TaskStatus.paused,
                );
                final canPauseAll = tasks.any(
                  (t) => t.status == TaskStatus.running,
                );
                final canResetAll = tasks.isNotEmpty;
                final canDeleteAll = tasks.isNotEmpty;

                return Column(
                  children: [
                    _buildBatchActionBar(
                      context,
                      tasks: tasks,
                      canRunAll: canRunAll,
                      canPauseAll: canPauseAll,
                      canResetAll: canResetAll,
                      canDeleteAll: canDeleteAll,
                    ),
                    Expanded(child: _buildTasksList(context, tasks)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_task_fab'),
        onPressed: _showCreateTaskDialog,
        tooltip: 'Add Stopwatch',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBatchActionBar(
    BuildContext context, {
    required List<TaskSnapshot> tasks,
    required bool canRunAll,
    required bool canPauseAll,
    required bool canResetAll,
    required bool canDeleteAll,
  }) {
    final buttonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Tooltip(
              message: 'Run All',
              child: OutlinedButton.icon(
                key: const Key('batch_run_all_btn'),
                style: buttonStyle,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run All'),
                onPressed: canRunAll ? _handleRunAll : null,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Pause All',
              child: OutlinedButton.icon(
                key: const Key('batch_pause_all_btn'),
                style: buttonStyle,
                icon: const Icon(Icons.pause, size: 18),
                label: const Text('Pause All'),
                onPressed: canPauseAll ? _handlePauseAll : null,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Reset All',
              child: OutlinedButton.icon(
                key: const Key('batch_reset_all_btn'),
                style: buttonStyle,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset All'),
                onPressed: canResetAll
                    ? () => _confirmResetAll(tasks.length)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Delete All',
              child: OutlinedButton.icon(
                key: const Key('batch_delete_all_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  iconColor: Colors.red,
                  side: canDeleteAll
                      ? BorderSide(color: Colors.red.shade300)
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete All'),
                onPressed: canDeleteAll
                    ? () => _confirmDeleteAll(tasks.length)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context, List<TaskSnapshot> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No stopwatches yet',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to create your first stopwatch',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredTasks = query.isEmpty
        ? tasks
        : tasks.where((t) => t.name.toLowerCase().contains(query)).toList();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No stopwatches found',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'No results matching "$_searchQuery"',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          // Màn rộng: Hiển thị dạng lưới (GridView)
          final crossAxisCount = constraints.maxWidth >= 960 ? 3 : 2;
          return GridView.builder(
            key: const Key('tasks_grid_view'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 210,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return TaskCard(
                key: ValueKey(task.id),
                task: task,
                service: _service,
                margin: EdgeInsets.zero,
                onTap: () => _navigateToDetail(task),
                onStart: () => _handleStart(task.id),
                onPause: () => _handlePause(task.id),
                onResume: () => _handleResume(task.id),
                onRename: () => _showRenameDialog(task),
                onChangeColor: () => _showChangeColorDialog(task),
                onDelete: () => _confirmDelete(task),
              );
            },
          );
        } else {
          // Màn hẹp: Hiển thị danh sách dọc (ListView)
          return ListView.builder(
            key: const Key('tasks_list_view'),
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return TaskCard(
                key: ValueKey(task.id),
                task: task,
                service: _service,
                onTap: () => _navigateToDetail(task),
                onStart: () => _handleStart(task.id),
                onPause: () => _handlePause(task.id),
                onResume: () => _handleResume(task.id),
                onRename: () => _showRenameDialog(task),
                onChangeColor: () => _showChangeColorDialog(task),
                onDelete: () => _confirmDelete(task),
              );
            },
          );
        }
      },
    );
  }
}
