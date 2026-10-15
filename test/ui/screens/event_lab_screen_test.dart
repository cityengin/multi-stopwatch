import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/lab/event_lab_runner.dart';
import 'package:multi_stopwatch/ui/screens/event_lab_screen.dart';
import 'package:multi_stopwatch/ui/screens/home_screen.dart';

import '../fakes/fake_stopwatch_service.dart';

void main() {
  group('EventLabScreen Widget Tests', () {
    late EventLabRunner runner;

    setUp(() {
      runner = EventLabRunner();
    });

    testWidgets('Hiển thị giao diện EventLabScreen ban đầu đúng chuẩn', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EventLabScreen(runner: runner)),
      );
      await tester.pump();

      // Kiểm tra tiêu đề và thanh AppBar
      expect(find.text('Event Loop Lab'), findsOneWidget);

      // Kiểm tra kịch bản mặc định và giải thích
      expect(find.text('scheduleMicrotask vs Timer'), findsOneWidget);
      expect(
        find.textContaining('Synchronous code runs to completion first.'),
        findsOneWidget,
      );

      // Kiểm tra thanh chú thích thứ tự ưu tiên 3 hàng đợi
      expect(find.text('1. SYNC'), findsOneWidget);
      expect(find.text('2. MICROTASK'), findsOneWidget);
      expect(find.text('3. EVENT'), findsOneWidget);

      // Trạng thái ban đầu chưa có kết quả
      expect(
        find.textContaining('No results for this scenario yet.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Chạy kịch bản microtaskVsTimer hiển thị thứ tự Sync -> Microtask -> Event',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: EventLabScreen(runner: runner)),
        );
        await tester.pump();

        // Bấm nút chạy kịch bản hiện tại
        await tester.tap(find.byKey(const Key('lab_run_scenario_btn')));
        await tester.pumpAndSettle();

        // Kiểm tra danh sách kết quả hiển thị 4 bước
        expect(
          find.textContaining('Measured execution order (4 steps)'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('lab_events_list')), findsOneWidget);

        // Kiểm tra các bước cụ thể
        expect(find.text('sync: start'), findsOneWidget);
        expect(find.text('sync: end'), findsOneWidget);
        expect(find.text('scheduleMicrotask'), findsOneWidget);
        expect(find.text('Timer.run'), findsOneWidget);

        // Kiểm tra các thẻ hàng đợi trong danh sách
        expect(
          find.descendant(
            of: find.byKey(const Key('lab_events_list')),
            matching: find.text('SYNC'),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('lab_events_list')),
            matching: find.text('MICROTASK'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('lab_events_list')),
            matching: find.text('EVENT'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Đổi kịch bản sang asyncGap và chạy kết quả chính xác', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EventLabScreen(runner: runner)),
      );
      await tester.pump();

      // Bấm vào dropdown và chọn kịch bản asyncGap
      await tester.tap(find.byKey(const Key('lab_scenario_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Async gap').last);
      await tester.pumpAndSettle();

      // Giải thích của kịch bản asyncGap được cập nhật
      expect(
        find.textContaining('Between awaiting an unfinished Future'),
        findsOneWidget,
      );

      // Chạy kịch bản asyncGap
      await tester.tap(find.byKey(const Key('lab_run_scenario_btn')));
      await tester.pumpAndSettle();

      // Kiểm tra kết quả hiển thị 5 bước của asyncGap
      expect(
        find.textContaining('Measured execution order (5 steps)'),
        findsOneWidget,
      );
      expect(find.text('microtask: counter = 1'), findsOneWidget);
      expect(find.text('worker: after await, counter = 1'), findsOneWidget);
      expect(find.text('Timer.run: counter = 2'), findsOneWidget);
    });

    testWidgets('Chạy tất cả 6 kịch bản cùng lúc bằng nút Chạy tất cả', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EventLabScreen(runner: runner)),
      );
      await tester.pump();

      // Bấm nút Chạy tất cả
      await tester.tap(find.byKey(const Key('lab_run_all_btn')));
      await tester.pumpAndSettle();

      // Kịch bản hiện tại (microtaskVsTimer) đã có kết quả
      expect(
        find.textContaining('Measured execution order (4 steps)'),
        findsOneWidget,
      );

      // Đổi sang kịch bản nestedMicrotasks, kết quả đã có sẵn mà không cần bấm chạy lại
      await tester.tap(find.byKey(const Key('lab_scenario_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Microtasks scheduling microtasks').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Measured execution order (4 steps)'),
        findsOneWidget,
      );
      expect(find.text('microtask 1: schedules microtask 2'), findsOneWidget);
      expect(find.text('microtask 2'), findsOneWidget);
    });

    testWidgets('Nút xóa kết quả đưa màn hình về trạng thái trống ban đầu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EventLabScreen(runner: runner)),
      );
      await tester.pump();

      // Chạy kịch bản
      await tester.tap(find.byKey(const Key('lab_run_scenario_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lab_events_list')), findsOneWidget);

      // Bấm nút xóa kết quả
      await tester.tap(find.byKey(const Key('lab_clear_btn')));
      await tester.pump();

      // Danh sách biến mất, hiện lại placeholder
      expect(find.byKey(const Key('lab_events_list')), findsNothing);
      expect(
        find.textContaining('No results for this scenario yet.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Điều hướng từ HomeScreen sang EventLabScreen qua nút Lab ở AppBar',
      (WidgetTester tester) async {
        final fakeService = FakeStopwatchService();

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(service: fakeService)),
        );
        await tester.pumpAndSettle();

        // Tìm và bấm nút Lab trên AppBar của HomeScreen
        expect(find.byKey(const Key('home_lab_btn')), findsOneWidget);
        await tester.tap(find.byKey(const Key('home_lab_btn')));
        await tester.pumpAndSettle();

        // Đã mở sang màn hình EventLabScreen
        expect(find.byType(EventLabScreen), findsOneWidget);
        expect(find.text('Event Loop Lab'), findsOneWidget);
      },
    );
  });
}
