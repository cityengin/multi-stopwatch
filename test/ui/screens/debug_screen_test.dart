import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/debug/stream_tracker.dart';
import 'package:multi_stopwatch/ui/scope/stopwatch_scope.dart';
import 'package:multi_stopwatch/ui/screens/debug_screen.dart';
import 'package:multi_stopwatch/ui/screens/home_screen.dart';
import 'package:multi_stopwatch/ui/screens/task_detail_screen.dart';

import '../fakes/fake_stopwatch_service.dart';

void main() {
  group('DebugScreen Widget Tests', () {
    late StreamTracker tracker;

    setUp(() {
      tracker = StreamTracker(historyLimit: 50);
    });

    tearDown(() async {
      await tracker.dispose();
    });

    testWidgets('Hiển thị giao diện DebugScreen ban đầu với 0 subscription', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DebugScreen(tracker: tracker),
        ),
      );
      await tester.pump();

      expect(find.text('Bộ theo dõi luồng (Debug)'), findsOneWidget);
      expect(find.text('Subscription đang hoạt động'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('active_subscriptions_badge')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(find.text('Chưa có sự kiện nào trong log.'), findsOneWidget);
    });

    testWidgets(
      'Cập nhật activeCount và danh sách log khi có sự kiện listen/cancel',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DebugScreen(tracker: tracker),
          ),
        );
        await tester.pump();

        final controller = StreamController<int>.broadcast();
        final trackedStream = tracker.track('test_stream', controller.stream);

        // Tạo subscription -> activeCount = 1, sinh log LISTEN
        final sub = trackedStream.listen((_) {});
        await tester.pump(Duration.zero);

        expect(
          find.descendant(
            of: find.byKey(const Key('active_subscriptions_badge')),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('LISTEN'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('test_stream'),
          ),
          findsOneWidget,
        );

        // Hủy subscription -> activeCount = 0, sinh log CANCEL
        sub.cancel();
        await tester.pump(Duration.zero);

        expect(
          find.descendant(
            of: find.byKey(const Key('active_subscriptions_badge')),
            matching: find.text('0'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('CANCEL'),
          ),
          findsOneWidget,
        );

        await controller.close();
      },
    );

    testWidgets('Lọc danh sách log bằng các FilterChip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DebugScreen(tracker: tracker),
        ),
      );
      await tester.pump();

      final controller = StreamController<int>.broadcast();
      final trackedStream = tracker.track('filter_stream', controller.stream);

      final sub = trackedStream.listen((_) {});
      await tester.pump(Duration.zero);
      sub.cancel();
      await tester.pump(Duration.zero);

      // Hiện tại có 1 LISTEN và 1 CANCEL trong log
      expect(find.byType(ListTile), findsNWidgets(2));

      // Bấm chip lọc LISTEN
      await tester.tap(find.widgetWithText(FilterChip, 'LISTEN'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('LISTEN'), findsWidgets);

      // Bấm chip lọc CANCEL
      await tester.tap(find.widgetWithText(FilterChip, 'CANCEL'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('CANCEL'), findsWidgets);

      // Bấm Tất cả để hiển thị lại đủ
      await tester.tap(find.widgetWithText(FilterChip, 'Tất cả'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ListTile), findsNWidgets(2));

      await controller.close();
    });

    testWidgets(
      'Lấy StreamTracker từ StopwatchScope khi không truyền vào constructor',
      (WidgetTester tester) async {
        final fakeService = FakeStopwatchService(tracker: tracker);

        await tester.pumpWidget(
          MaterialApp(
            home: StopwatchScope(
              service: fakeService,
              tracker: tracker,
              child: const DebugScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Bộ theo dõi luồng (Debug)'), findsOneWidget);
        expect(find.text('Subscription đang hoạt động'), findsOneWidget);
      },
    );

    testWidgets(
      'Demo cho thầy: Thoát màn hình TaskDetailScreen thì số subscription giảm rõ rệt',
      (WidgetTester tester) async {
        final fakeService = FakeStopwatchService(tracker: tracker);
        await fakeService.createTask(
          name: 'Đồng hồ demo thầy',
          colorValue: Colors.red.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StopwatchScope(
              service: fakeService,
              tracker: tracker,
              child: HomeScreen(service: fakeService),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ban đầu ở HomeScreen: 1 subscription của HomeScreen lắng nghe tasksStream
        final initialActive = tracker.activeCount;
        expect(initialActive, greaterThanOrEqualTo(1));

        // Mở TaskDetailScreen
        await tester.tap(find.text('Đồng hồ demo thầy'));
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailScreen), findsOneWidget);
        // TaskDetailScreen listen thêm tasksStream và elapsedStream -> activeCount tăng
        final detailActive = tracker.activeCount;
        expect(detailActive, greaterThan(initialActive));

        // Thoát màn hình chi tiết (Back)
        Navigator.of(tester.element(find.byType(TaskDetailScreen))).pop();
        await tester.pumpAndSettle();

        // Sau khi thoát, màn chi tiết unmount -> số subscription giảm trở về như cũ
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(tracker.activeCount, lessThan(detailActive));
        expect(tracker.activeCount, initialActive);

        // Kiểm tra log trong tracker đã ghi nhận các sự kiện cancel của task detail
        final cancelEvents = tracker.history.where(
          (e) => e.kind == StreamLogKind.cancel,
        );
        expect(cancelEvents, isNotEmpty);
      },
    );
  });
}
