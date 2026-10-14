import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/main.dart';

void main() {
  testWidgets('MultiStopwatchApp khởi tạo và render Scaffold thành công', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryTaskRepository();

    // Dựng widget gốc với InMemoryTaskRepository
    await tester.pumpWidget(MultiStopwatchApp(repository: repo));

    // Chờ FutureBuilder hoàn tất nạp StopwatchManager
    await tester.pumpAndSettle();

    // Xác nhận render ra Scaffold trống theo yêu cầu bước 1
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
