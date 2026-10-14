import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/models/task_status.dart';
import 'package:multi_stopwatch/ui/screens/task_detail_screen.dart';

import '../fakes/fake_stopwatch_service.dart';

void main() {
  group('TaskDetailScreen Widget Tests', () {
    late FakeStopwatchService fakeService;

    setUp(() {
      fakeService = FakeStopwatchService();
    });

    testWidgets(
      'Hiển thị tên, số lớn thời gian và các nút điều khiển ở trạng thái idle',
      (WidgetTester tester) async {
        final task = await fakeService.createTask(
          name: 'Chạy việt dã',
          colorValue: Colors.blue.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TaskDetailScreen(
              taskId: task.id,
              initialTask: task,
              service: fakeService,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Chạy việt dã'), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('00:00.00'), findsOneWidget);

        // Nút Bắt đầu bật
        expect(find.byKey(const Key('detail_start_btn')), findsOneWidget);

        // Nút Reset và Lap bị disable khi idle
        final resetBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('detail_reset_btn')),
        );
        expect(resetBtn.onPressed, isNull);

        final lapBtn = tester.widget<FilledButton>(
          find.byKey(const Key('detail_lap_btn')),
        );
        expect(lapBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Điều khiển Start, ghi nhiều Lap kèm chênh lệch Delta và Reset',
      (WidgetTester tester) async {
        final task = await fakeService.createTask(
          name: 'Bơi 100m',
          colorValue: Colors.teal.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TaskDetailScreen(
              taskId: task.id,
              initialTask: task,
              service: fakeService,
            ),
          ),
        );
        await tester.pump();

        // 1. Bấm Bắt đầu
        await tester.tap(find.byKey(const Key('detail_start_btn')));
        await tester.pump();

        expect(find.text('Running'), findsOneWidget);
        expect(find.byKey(const Key('detail_pause_btn')), findsOneWidget);

        // 2. Cập nhật thời gian chặng 1: 30s
        fakeService.emitElapsed(task.id, const Duration(seconds: 30));
        await tester.pump();

        // Bấm nút Lap ghi chặng 1
        await tester.tap(find.byKey(const Key('detail_lap_btn')));
        await tester.pump();

        expect(find.text('#1'), findsOneWidget);
        expect(find.text('00:30.00'), findsWidgets);
        expect(find.text('--:--.--'), findsOneWidget); // Lap 1 delta là null

        // 3. Cập nhật thời gian chặng 2: 55s (vòng 2 mất 25s, nhanh hơn vòng 1 5s)
        fakeService.emitElapsed(task.id, const Duration(seconds: 55));
        await tester.pump();

        // Bấm nút Lap ghi chặng 2
        await tester.tap(find.byKey(const Key('detail_lap_btn')));
        await tester.pump();

        expect(find.text('#2'), findsOneWidget);
        expect(find.text('-00:05.00'), findsOneWidget); // Nhanh hơn 5 giây
        expect(find.text('Fastest'), findsOneWidget);

        // 4. Bấm Tạm dừng
        await tester.tap(find.byKey(const Key('detail_pause_btn')));
        await tester.pump();

        expect(find.text('Paused'), findsOneWidget);
        expect(find.byKey(const Key('detail_resume_btn')), findsOneWidget);

        // 5. Bấm Đặt lại (Reset)
        await tester.tap(find.byKey(const Key('detail_reset_btn')));
        await tester.pump();

        expect(find.text('Ready'), findsOneWidget);
        expect(fakeService.currentTasks.first.status, TaskStatus.idle);
        expect(
          find.text(
            'No laps recorded yet.\nTap "Lap" while running to record lap split times.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Rời màn hình TaskDetailScreen hủy an toàn mọi subscription', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ thoát',
        colorValue: Colors.red.toARGB32(),
      );

      // Khởi tạo Navigator với 2 màn hình
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(
                        taskId: task.id,
                        initialTask: task,
                        service: fakeService,
                      ),
                    ),
                  );
                },
                child: const Text('Mở chi tiết'),
              ),
            ),
          ),
        ),
      );

      // Mở màn hình chi tiết
      await tester.tap(find.text('Mở chi tiết'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailScreen), findsOneWidget);

      // Thoát khỏi màn hình chi tiết (pop)
      Navigator.of(tester.element(find.byType(TaskDetailScreen))).pop();
      await tester.pumpAndSettle();

      // Màn hình chi tiết đã bị hủy bỏ an toàn
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(find.text('Mở chi tiết'), findsOneWidget);
    });
  });
}
