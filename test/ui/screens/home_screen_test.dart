import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/ui/scope/stopwatch_scope.dart';
import 'package:multi_stopwatch/ui/screens/home_screen.dart';
import 'package:multi_stopwatch/ui/widgets/task_card.dart';

import '../fakes/fake_stopwatch_service.dart';

void main() {
  group('HomeScreen UI & StreamBuilder Tests', () {
    late FakeStopwatchService fakeService;

    setUp(() {
      fakeService = FakeStopwatchService();
    });

    testWidgets('Hiển thị giao diện rỗng khi chưa có đồng hồ nào', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );

      // Chờ frame đầu tiên dựng từ initialData
      await tester.pump();

      expect(find.text('Chưa có đồng hồ nào'), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
    });

    testWidgets('Hiển thị danh sách các thẻ TaskCard khi có đồng hồ', (
      WidgetTester tester,
    ) async {
      await fakeService.createTask(
        name: 'Học bài',
        colorValue: Colors.blue.toARGB32(),
      );
      await fakeService.createTask(
        name: 'Chạy bộ',
        colorValue: Colors.green.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );
      await tester.pump();

      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(find.text('Học bài'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('Sẵn sàng'), findsNWidgets(2));
    });

    testWidgets('Thêm đồng hồ mới qua FAB và Dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );
      await tester.pump();

      // Nhấn FAB để mở dialog thêm đồng hồ
      await tester.tap(find.byKey(const Key('add_task_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Thêm đồng hồ mới'), findsOneWidget);

      // Nhập tên
      await tester.enterText(find.byType(TextField), 'Đọc sách');
      await tester.pump();

      // Bấm nút Tạo
      await tester.tap(find.text('Tạo'));
      await tester.pumpAndSettle();

      // Xác nhận task mới xuất hiện trên UI
      expect(find.text('Đọc sách'), findsOneWidget);
      expect(fakeService.currentTasks.length, 1);
      expect(fakeService.currentTasks.first.name, 'Đọc sách');
    });

    testWidgets('Nút Start / Pause / Resume chuyển trạng thái nhanh', (
      WidgetTester tester,
    ) async {
      final task = await fakeService.createTask(
        name: 'Tập gym',
        colorValue: Colors.orange.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );
      await tester.pump();

      // Ban đầu là idle -> nút "Bắt đầu"
      expect(find.text('Sẵn sàng'), findsOneWidget);
      final startBtn = find.byKey(Key('start_btn_${task.id}'));
      expect(startBtn, findsOneWidget);

      // Bấm Bắt đầu -> chuyển running
      await tester.tap(startBtn);
      await tester.pump();

      expect(find.text('Đang chạy'), findsOneWidget);
      final pauseBtn = find.byKey(Key('pause_btn_${task.id}'));
      expect(pauseBtn, findsOneWidget);

      // Bấm Tạm dừng -> chuyển paused
      await tester.tap(pauseBtn);
      await tester.pump();

      expect(find.text('Tạm dừng'), findsOneWidget);
      final resumeBtn = find.byKey(Key('resume_btn_${task.id}'));
      expect(resumeBtn, findsOneWidget);

      // Bấm Tiếp tục -> chuyển running
      await tester.tap(resumeBtn);
      await tester.pump();

      expect(find.text('Đang chạy'), findsOneWidget);
    });

    testWidgets('Đổi tên đồng hồ qua menu tùy chọn', (
      WidgetTester tester,
    ) async {
      await fakeService.createTask(
        name: 'Tên cũ',
        colorValue: Colors.blue.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );
      await tester.pump();

      // Mở menu tùy chọn
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Chọn Đổi tên
      await tester.tap(find.text('Đổi tên'));
      await tester.pumpAndSettle();

      expect(find.text('Đổi tên đồng hồ'), findsOneWidget);

      // Nhập tên mới
      await tester.enterText(find.byType(TextField), 'Tên mới đã đổi');
      await tester.pump();

      // Bấm Lưu
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Tên mới đã đổi'), findsOneWidget);
      expect(fakeService.currentTasks.first.name, 'Tên mới đã đổi');
    });

    testWidgets('Xóa đồng hồ qua menu tùy chọn và xác nhận', (
      WidgetTester tester,
    ) async {
      await fakeService.createTask(
        name: 'Cần xóa',
        colorValue: Colors.red.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(service: fakeService),
        ),
      );
      await tester.pump();

      expect(find.text('Cần xóa'), findsOneWidget);

      // Mở menu tùy chọn
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Chọn Xóa
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);

      // Xác nhận nút Xóa trong Dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Cần xóa'), findsNothing);
      expect(fakeService.currentTasks.isEmpty, isTrue);
    });

    testWidgets(
      'Lấy StopwatchService từ StopwatchScope khi không truyền service qua constructor',
      (WidgetTester tester) async {
        await fakeService.createTask(
          name: 'Task từ Scope',
          colorValue: Colors.purple.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StopwatchScope(
              service: fakeService,
              child: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Task từ Scope'), findsOneWidget);
      },
    );
  });
}
