import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/stopwatch_task.dart';
import 'task_repository.dart';

/// [TaskRepository] lưu trên máy bằng shared_preferences, dữ liệu dạng JSON.
///
/// Định dạng: một key duy nhất chứa `{"version": 1, "tasks": [...]}`.
/// - Vì sao một key cho cả danh sách: mỗi lần ghi là một lần ghi nguyên khối,
///   giữ được thứ tự và không bao giờ có trạng thái "ghi được một nửa". Dữ liệu
///   vài chục đồng hồ rất nhỏ nên ghi lại toàn bộ không tốn đáng kể.
/// - Vì sao có `version`: khi đổi cấu trúc dữ liệu ở bản sau, code đọc biết
///   phải chuyển đổi thế nào thay vì đọc nhầm dữ liệu cũ.
///
/// Vì sao gọi chồng nhau vẫn an toàn dù mỗi lệnh đọc–sửa–ghi cả danh sách:
/// `SharedPreferences` cập nhật cache trong bộ nhớ đồng bộ ngay khi `setString`
/// được gọi (trước khi ghi xuống đĩa), nên lệnh sau luôn đọc thấy kết quả của
/// lệnh trước.
class LocalTaskRepository implements TaskRepository {
  /// [preferences] được truyền vào (dependency injection) để test dùng bản giả
  /// của shared_preferences; [key] cho phép tách dữ liệu nhiều hồ sơ.
  LocalTaskRepository(this._preferences, {this.key = defaultKey});

  static const defaultKey = 'multi_stopwatch.tasks';

  /// Phiên bản định dạng dữ liệu hiện tại.
  static const schemaVersion = 1;

  final SharedPreferences _preferences;
  final String key;

  @override
  Future<List<StopwatchTask>> loadAll() async => _read();

  @override
  Future<void> upsert(StopwatchTask task) async {
    final tasks = _read();
    final index = tasks.indexWhere((existing) => existing.id == task.id);
    if (index >= 0) {
      tasks[index] = task;
    } else {
      tasks.add(task);
    }
    await _write(tasks);
  }

  @override
  Future<void> delete(String taskId) async {
    final tasks = _read();
    final before = tasks.length;
    tasks.removeWhere((task) => task.id == taskId);
    if (tasks.length != before) await _write(tasks);
  }

  List<StopwatchTask> _read() {
    final raw = _preferences.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gốc dữ liệu phải là object JSON.');
      }
      final version = decoded['version'];
      if (version != schemaVersion) {
        throw FormatException('Không hỗ trợ phiên bản dữ liệu "$version".');
      }
      final items = decoded['tasks'];
      if (items is! List<dynamic>) {
        throw const FormatException('Trường "tasks" phải là list.');
      }
      final tasks = <StopwatchTask>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Mỗi đồng hồ phải là object JSON.');
        }
        tasks.add(StopwatchTask.fromJson(item));
      }
      return tasks;
    } on FormatException catch (error) {
      throw StorageException('Dữ liệu đồng hồ đã lưu bị hỏng.', cause: error);
    }
  }

  Future<void> _write(List<StopwatchTask> tasks) async {
    final raw = jsonEncode({
      'version': schemaVersion,
      'tasks': [for (final task in tasks) task.toJson()],
    });
    final bool saved;
    try {
      saved = await _preferences.setString(key, raw);
    } on Exception catch (error) {
      throw StorageException('Không ghi được dữ liệu xuống máy.', cause: error);
    }
    if (!saved) throw StorageException('Không ghi được dữ liệu xuống máy.');
  }
}
