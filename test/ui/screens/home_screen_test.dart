import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/ui/scope/stopwatch_scope.dart';
import 'package:multi_stopwatch/ui/screens/home_screen.dart';
import 'package:multi_stopwatch/ui/screens/task_detail_screen.dart';
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
        MaterialApp(home: HomeScreen(service: fakeService)),
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
        MaterialApp(home: HomeScreen(service: fakeService)),
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
        MaterialApp(home: HomeScreen(service: fakeService)),
      );
      await tester.pump();

      // Nhấn FAB để mở dialog thêm đồng hồ
      await tester.tap(find.byKey(const Key('add_task_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Thêm đồng hồ mới'), findsOneWidget);

      // Nhập tên
      await tester.enterText(find.byType(TextField).last, 'Đọc sách');
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
        MaterialApp(home: HomeScreen(service: fakeService)),
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
        MaterialApp(home: HomeScreen(service: fakeService)),
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
      await tester.enterText(find.byType(TextField).last, 'Tên mới đã đổi');
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
        MaterialApp(home: HomeScreen(service: fakeService)),
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

    testWidgets('Nhấn vào thẻ TaskCard điều hướng sang TaskDetailScreen', (
      WidgetTester tester,
    ) async {
      await fakeService.createTask(
        name: 'Đồng hồ chi tiết',
        colorValue: Colors.indigo.toARGB32(),
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(service: fakeService)),
      );
      await tester.pump();

      // Nhấn vào tên task trên card để điều hướng
      await tester.tap(find.text('Đồng hồ chi tiết'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.text('Danh sách vòng (0)'), findsOneWidget);
    });

    testWidgets(
      'Tìm kiếm đồng hồ dùng debounce của core: lọc chính xác và xóa tìm kiếm',
      (WidgetTester tester) async {
        await fakeService.createTask(
          name: 'Học Flutter',
          colorValue: Colors.blue.toARGB32(),
        );
        await fakeService.createTask(
          name: 'Học tiếng Anh',
          colorValue: Colors.green.toARGB32(),
        );
        await fakeService.createTask(
          name: 'Chạy bộ',
          colorValue: Colors.orange.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(service: fakeService)),
        );
        await tester.pump();

        // Ban đầu thấy cả 3 đồng hồ
        expect(find.byType(TaskCard), findsNWidgets(3));

        // Nhập vào ô tìm kiếm: "tiếng"
        await tester.enterText(
          find.byKey(const Key('home_search_field')),
          'tiếng',
        );
        // Chưa đủ 300ms debounce -> chưa lọc
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TaskCard), findsNWidgets(3));

        // Sau 300ms debounce -> đã lọc
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(TaskCard), findsOneWidget);
        expect(find.text('Học tiếng Anh'), findsOneWidget);
        expect(find.text('Học Flutter'), findsNothing);
        expect(find.text('Chạy bộ'), findsNothing);

        // Nhập từ khóa không tồn tại
        await tester.enterText(
          find.byKey(const Key('home_search_field')),
          'Bơi lội',
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(TaskCard), findsNothing);
        expect(find.text('Không tìm thấy đồng hồ nào'), findsOneWidget);
        expect(
          find.text('Không có kết quả khớp với "Bơi lội"'),
          findsOneWidget,
        );

        // Bấm nút xóa tìm kiếm
        await tester.tap(find.byKey(const Key('home_search_clear_btn')));
        await tester.pumpAndSettle();

        // Danh sách trở lại 3 đồng hồ
        expect(find.byType(TaskCard), findsNWidgets(3));
      },
    );

    testWidgets(
      'Layout responsive qua LayoutBuilder: màn hẹp dạng ListView, màn rộng dạng GridView',
      (WidgetTester tester) async {
        await fakeService.createTask(
          name: 'Task 1',
          colorValue: Colors.blue.toARGB32(),
        );
        await fakeService.createTask(
          name: 'Task 2',
          colorValue: Colors.green.toARGB32(),
        );

        // 1. Kiểm tra màn hình hẹp (< 600px): hiển thị ListView
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(service: fakeService)),
        );
        await tester.pump();

        expect(find.byKey(const Key('tasks_list_view')), findsOneWidget);
        expect(find.byKey(const Key('tasks_grid_view')), findsNothing);

        // 2. Đổi kích thước sang màn hình rộng (>= 600px): hiển thị GridView
        tester.view.physicalSize = const Size(800, 600);
        await tester.pump();

        expect(find.byKey(const Key('tasks_grid_view')), findsOneWidget);
        expect(find.byKey(const Key('tasks_list_view')), findsNothing);
      },
    );
  });
}
