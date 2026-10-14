import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/ui/scope/stopwatch_scope.dart';
import 'package:multi_stopwatch/ui/widgets/elapsed_text.dart';

import '../fakes/fake_stopwatch_service.dart';

void main() {
  group('ElapsedText Widget Tests', () {
    late FakeStopwatchService fakeService;

    setUp(() {
      fakeService = FakeStopwatchService();
    });

    testWidgets('Hiển thị ngay initialElapsed ở frame đầu tiên', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ 1',
        colorValue: Colors.blue.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedText(
              taskId: task.id,
              initialElapsed: const Duration(seconds: 45, milliseconds: 120),
              service: fakeService,
            ),
          ),
        ),
      );

      // Frame đầu tiên nhận ngay initialElapsed
      expect(find.text('00:45.12'), findsOneWidget);
    });

    testWidgets('Cập nhật giá trị khi elapsedStream phát dữ liệu mới', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ 2',
        colorValue: Colors.green.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedText(
              taskId: task.id,
              initialElapsed: Duration.zero,
              service: fakeService,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:00.00'), findsOneWidget);

      // Giả lập đồng hồ phát nhịp tick thời gian
      fakeService.emitElapsed(
        task.id,
        const Duration(minutes: 1, seconds: 5, milliseconds: 780),
      );
      await tester.pump();

      expect(find.text('01:05.78'), findsOneWidget);
    });

    testWidgets('Lấy service từ StopwatchScope thành công khi không truyền qua constructor', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ Scope',
        colorValue: Colors.orange.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StopwatchScope(
            service: fakeService,
            child: Scaffold(
              body: ElapsedText(
                taskId: task.id,
                initialElapsed: const Duration(seconds: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:10.00'), findsOneWidget);

      fakeService.emitElapsed(task.id, const Duration(seconds: 15, milliseconds: 500));
      await tester.pump();

      expect(find.text('00:15.50'), findsOneWidget);
    });

    testWidgets('Hiển thị lỗi --:--.-- khi stream gặp exception', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ lỗi',
        colorValue: Colors.red.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedText(
              taskId: task.id,
              initialElapsed: Duration.zero,
              service: fakeService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Giả lập stream gặp lỗi
      fakeService.emitElapsedError(task.id, Exception('Mất kết nối Timer'));
      await tester.pump();

      expect(find.text('--:--.--'), findsOneWidget);
    });

    testWidgets('Nhiều ElapsedText chạy song song cập nhật độc lập', (
      WidgetTester tester,
    ) async {
      final task1 = await fakeService.createTask(
        name: 'Đồng hồ A',
        colorValue: Colors.blue.toARGB32(),
      );
      final task2 = await fakeService.createTask(
        name: 'Đồng hồ B',
        colorValue: Colors.purple.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElapsedText(
                  taskId: task1.id,
                  initialElapsed: Duration.zero,
                  service: fakeService,
                ),
                ElapsedText(
                  taskId: task2.id,
                  initialElapsed: const Duration(seconds: 30),
                  service: fakeService,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text('00:30.00'), findsOneWidget);

      // Cập nhật chỉ đồng hồ 1
      fakeService.emitElapsed(task1.id, const Duration(seconds: 1, milliseconds: 500));
      await tester.pump();

      expect(find.text('00:01.50'), findsOneWidget);
      expect(find.text('00:30.00'), findsOneWidget);

      // Cập nhật đồng hồ 2
      fakeService.emitElapsed(task2.id, const Duration(seconds: 35, milliseconds: 200));
      await tester.pump();

      expect(find.text('00:01.50'), findsOneWidget);
      expect(find.text('00:35.20'), findsOneWidget);
    });
  });
}
