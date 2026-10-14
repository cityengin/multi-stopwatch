import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/stopwatch_manager.dart';
import 'core/storage/local_task_repository.dart';
import 'core/storage/task_repository.dart';
import 'ui/scope/stopwatch_scope.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const MultiStopwatchApp());
}

/// Widget gốc của ứng dụng Multi-Stopwatch.
///
/// Quản lý vòng đời của [StopwatchManager] duy nhất trong toàn bộ ứng dụng:
/// khởi tạo trong [State.initState] và giải phóng trong [State.dispose].
class MultiStopwatchApp extends StatefulWidget {
  const MultiStopwatchApp({super.key, this.repository});

  /// [TaskRepository] truyền vào để phục vụ kiểm thử hoặc ghi đè nơi lưu trữ.
  final TaskRepository? repository;

  @override
  State<MultiStopwatchApp> createState() => _MultiStopwatchAppState();
}

class _MultiStopwatchAppState extends State<MultiStopwatchApp> {
  late final Future<StopwatchManager> _managerFuture;
  StopwatchManager? _manager;

  @override
  void initState() {
    super.initState();
    // Tạo duy nhất một StopwatchManager trong initState theo đúng quy ước kiến trúc.
    _managerFuture = _initManager();
  }

  Future<StopwatchManager> _initManager() async {
    final TaskRepository repo;
    if (widget.repository != null) {
      repo = widget.repository!;
    } else {
      WidgetsFlutterBinding.ensureInitialized();
      final preferences = await SharedPreferences.getInstance();
      repo = LocalTaskRepository(preferences);
    }
    final manager = await StopwatchManager.open(repository: repo);
    _manager = manager;
    return manager;
  }

  @override
  void dispose() {
    // Bắt buộc giải phóng StopwatchManager duy nhất khi widget gốc unmount.
    _manager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Stopwatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: FutureBuilder<StopwatchManager>(
        future: _managerFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Lỗi tải dữ liệu: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // Cung cấp StopwatchManager xuống toàn bộ widget tree qua StopwatchScope
          return StopwatchScope(
            service: snapshot.requireData,
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}

/// Alias đảm bảo tương thích ngược.
typedef MyApp = MultiStopwatchApp;
