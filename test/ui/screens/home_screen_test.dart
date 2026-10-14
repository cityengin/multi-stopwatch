import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';
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

    group('Batch Operations Toolbar Tests', () {
      testWidgets(
        'Kiểm tra trạng thái enable/disable của 4 nút thao tác hàng loạt theo dữ liệu',
        (WidgetTester tester) async {
          // 1. Khi danh sách rỗng: tất cả nút batch đều disabled, nút Thêm enabled
          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          final addBtn = tester.widget<FilledButton>(
            find.byKey(const Key('batch_add_btn')),
          );
          final runAllBtn = tester.widget<OutlinedButton>(
            find.byKey(const Key('batch_run_all_btn')),
          );
          final pauseAllBtn = tester.widget<OutlinedButton>(
            find.byKey(const Key('batch_pause_all_btn')),
          );
          final resetAllBtn = tester.widget<OutlinedButton>(
            find.byKey(const Key('batch_reset_all_btn')),
          );
          final deleteAllBtn = tester.widget<OutlinedButton>(
            find.byKey(const Key('batch_delete_all_btn')),
          );

          expect(addBtn.enabled, isTrue);
          expect(runAllBtn.enabled, isFalse);
          expect(pauseAllBtn.enabled, isFalse);
          expect(resetAllBtn.enabled, isFalse);
          expect(deleteAllBtn.enabled, isFalse);

          // 2. Thêm 1 đồng hồ ở trạng thái idle:
          // Chạy tất cả: bật; Pause tất cả: tắt; Reset/Xóa tất cả: bật
          await fakeService.createTask(
            name: 'Đồng hồ 1',
            colorValue: Colors.blue.toARGB32(),
          );
          await tester.pump();

          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_run_all_btn')),
                )
                .enabled,
            isTrue,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_pause_all_btn')),
                )
                .enabled,
            isFalse,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_reset_all_btn')),
                )
                .enabled,
            isTrue,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_delete_all_btn')),
                )
                .enabled,
            isTrue,
          );

          // 3. Chạy đồng hồ 1 (status: running):
          // Chạy tất cả: tắt (không còn idle/paused); Pause tất cả: bật
          await fakeService.start('task_1');
          await tester.pump();

          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_run_all_btn')),
                )
                .enabled,
            isFalse,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_pause_all_btn')),
                )
                .enabled,
            isTrue,
          );

          // 4. Thêm đồng hồ 2 (idle):
          // Lúc này có cả running (đồng hồ 1) và idle (đồng hồ 2)
          // -> Cả Chạy tất cả và Pause tất cả đều bật
          await fakeService.createTask(
            name: 'Đồng hồ 2',
            colorValue: Colors.orange.toARGB32(),
          );
          await tester.pump();

          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_run_all_btn')),
                )
                .enabled,
            isTrue,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('batch_pause_all_btn')),
                )
                .enabled,
            isTrue,
          );
        },
      );

      testWidgets(
        'Bấm "Chạy tất cả" và "Pause tất cả" gọi đúng hàm trên service',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task A',
            colorValue: Colors.blue.toARGB32(),
          );
          await fakeService.createTask(
            name: 'Task B',
            colorValue: Colors.red.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          expect(fakeService.runAllCalls, 0);
          expect(fakeService.pauseAllCalls, 0);

          // Bấm "Chạy tất cả"
          final runBtn = find.byKey(const Key('batch_run_all_btn'));
          await tester.ensureVisible(runBtn);
          await tester.tap(runBtn);
          await tester.pump();

          expect(fakeService.runAllCalls, 1);
          expect(
            fakeService.currentTasks.every(
              (t) => t.status == TaskStatus.running,
            ),
            isTrue,
          );

          // Bấm "Pause tất cả"
          final pauseBtn = find.byKey(const Key('batch_pause_all_btn'));
          await tester.ensureVisible(pauseBtn);
          await tester.tap(pauseBtn);
          await tester.pump();

          expect(fakeService.pauseAllCalls, 1);
          expect(
            fakeService.currentTasks.every(
              (t) => t.status == TaskStatus.paused,
            ),
            isTrue,
          );
        },
      );

      testWidgets(
        'Bấm "Reset tất cả" hiện dialog nêu số lượng: Hủy không gọi, xác nhận gọi đúng 1 lần',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );
          await fakeService.createTask(
            name: 'Task 2',
            colorValue: Colors.green.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          final resetBtn = find.byKey(const Key('batch_reset_all_btn'));

          // 1. Bấm Reset tất cả
          await tester.ensureVisible(resetBtn);
          await tester.tap(resetBtn);
          await tester.pumpAndSettle();

          // Kiểm tra dialog
          expect(find.text('Xác nhận reset tất cả'), findsOneWidget);
          expect(
            find.text('Reset toàn bộ 2 đồng hồ về 00:00 và xóa hết lap?'),
            findsOneWidget,
          );

          // Bấm Hủy -> không gọi API
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();

          expect(fakeService.resetAllCalls, 0);
          expect(find.text('Xác nhận reset tất cả'), findsNothing);

          // 2. Mở lại dialog và bấm xác nhận Reset
          await tester.ensureVisible(resetBtn);
          await tester.tap(resetBtn);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Reset'));
          await tester.pumpAndSettle();

          expect(fakeService.resetAllCalls, 1);
        },
      );

      testWidgets(
        'Bấm "Xóa tất cả" hiện dialog nêu số lượng: Hủy không gọi, xác nhận gọi đúng 1 lần',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );
          await fakeService.createTask(
            name: 'Task 2',
            colorValue: Colors.green.toARGB32(),
          );
          await fakeService.createTask(
            name: 'Task 3',
            colorValue: Colors.purple.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          final deleteBtn = find.byKey(const Key('batch_delete_all_btn'));

          // 1. Bấm Xóa tất cả
          await tester.ensureVisible(deleteBtn);
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();

          // Kiểm tra dialog nêu rõ số lượng đồng hồ
          expect(find.text('Xác nhận xóa tất cả'), findsOneWidget);
          expect(
            find.text(
              'Xóa toàn bộ 3 đồng hồ? Hành động này không thể hoàn tác.',
            ),
            findsOneWidget,
          );

          // Bấm Hủy -> không gọi API
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();

          expect(fakeService.deleteAllCalls, 0);
          expect(fakeService.currentTasks.length, 3);
          expect(find.text('Xác nhận xóa tất cả'), findsNothing);

          // 2. Mở lại dialog và xác nhận Xóa
          await tester.ensureVisible(deleteBtn);
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Xóa'));
          await tester.pumpAndSettle();

          expect(fakeService.deleteAllCalls, 1);
          expect(fakeService.currentTasks.isEmpty, isTrue);
          expect(find.text('Chưa có đồng hồ nào'), findsOneWidget);
        },
      );

      testWidgets(
        'Màn hình hẹp (320px width) cho phép cuộn ngang thanh công cụ, không bị RenderFlex overflow',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await fakeService.createTask(
            name: 'Task Mini',
            colorValue: Colors.blue.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          // Xác nhận cuộn ngang hoạt động và không có lỗi overflow
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('batch_add_btn')), findsOneWidget);
          expect(find.byKey(const Key('batch_run_all_btn')), findsOneWidget);
        },
      );

      testWidgets(
        'Xử lý lỗi khi runAll: bắt lỗi và hiển thị SnackBar, không crash',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          fakeService.nextRunAllError = StorageException('Lỗi ổ cứng');
          final runBtn = find.byKey(const Key('batch_run_all_btn'));
          await tester.ensureVisible(runBtn);
          await tester.tap(runBtn);
          await tester.pump();

          expect(find.text('Lỗi lưu trữ khi chạy tất cả'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Xử lý lỗi khi pauseAll: bắt lỗi và hiển thị SnackBar, không crash',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );
          await fakeService.start('task_1');

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          fakeService.nextPauseAllError = StorageException('Lỗi pause');
          final pauseBtn = find.byKey(const Key('batch_pause_all_btn'));
          await tester.ensureVisible(pauseBtn);
          await tester.tap(pauseBtn);
          await tester.pump();

          expect(find.text('Lỗi lưu trữ khi tạm dừng tất cả'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Xử lý lỗi khi resetAll: bắt lỗi và hiển thị SnackBar, không crash',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          fakeService.nextResetAllError = StorageException('Lỗi reset');
          final resetBtn = find.byKey(const Key('batch_reset_all_btn'));
          await tester.ensureVisible(resetBtn);
          await tester.tap(resetBtn);
          await tester.pumpAndSettle();

          expect(find.text('Xác nhận reset tất cả'), findsOneWidget);
          await tester.tap(find.text('Reset'));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Lỗi lưu trữ khi reset tất cả'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Xử lý lỗi khi deleteAll: bắt lỗi và hiển thị SnackBar, không crash',
        (WidgetTester tester) async {
          await fakeService.createTask(
            name: 'Task 1',
            colorValue: Colors.blue.toARGB32(),
          );

          await tester.pumpWidget(
            MaterialApp(home: HomeScreen(service: fakeService)),
          );
          await tester.pump();

          fakeService.nextDeleteAllError = StorageException('Lỗi delete');
          final deleteBtn = find.byKey(const Key('batch_delete_all_btn'));
          await tester.ensureVisible(deleteBtn);
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();

          expect(find.text('Xác nhận xóa tất cả'), findsOneWidget);
          await tester.tap(find.text('Xóa'));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Lỗi lưu trữ khi xóa tất cả'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
