import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/debug/stream_tracker.dart';
import 'package:multi_stopwatch/ui/scope/stopwatch_scope.dart';
import 'package:multi_stopwatch/ui/screens/home_screen.dart';
import 'package:multi_stopwatch/ui/screens/task_detail_screen.dart';
import 'package:multi_stopwatch/ui/widgets/elapsed_text.dart';

import 'fakes/fake_stopwatch_service.dart';

void main() {
  group('Subscription Lifecycle & StreamTracker Widget Tests (Bước 8)', () {
    late StreamTracker tracker;
    late FakeStopwatchService fakeService;

    setUp(() {
      tracker = StreamTracker(historyLimit: 100);
      fakeService = FakeStopwatchService(tracker: tracker);
    });

    tearDown(() async {
      await fakeService.dispose();
      await tracker.dispose();
    });

    test('FakeStopwatchService viết tay hoạt động chính xác và đếm qua StreamTracker', () async {
      final task = await fakeService.createTask(
        name: 'Đồng hồ unit test',
        colorValue: Colors.blue.toARGB32(),
      );

      expect(tracker.activeCount, 0);
      expect(tracker.activeBySource, isEmpty);

      // 1. Listen tasksStream
      final tasksSub = fakeService.tasksStream.listen((_) {});
      expect(tracker.activeCount, 1);
      expect(tracker.activeBySource['tasksStream'], 1);

      // 2. Listen elapsedStream
      final elapsedSub = fakeService.elapsedStream(task.id).listen((_) {});
      expect(tracker.activeCount, 2);
      expect(tracker.activeBySource['elapsedStream:${task.id}'], 1);

      // 3. Cancel elapsedStream
      await elapsedSub.cancel();
      expect(tracker.activeCount, 1);
      expect(
        tracker.activeBySource.containsKey('elapsedStream:${task.id}'),
        isFalse,
      );

      // 4. Cancel tasksStream
      await tasksSub.cancel();
      expect(tracker.activeCount, 0);
      expect(tracker.activeBySource, isEmpty);

      // 5. Kiểm tra log history ghi nhận đúng các sự kiện
      final listenEvents = tracker.history.where(
        (e) => e.kind == StreamLogKind.listen,
      );
      final cancelEvents = tracker.history.where(
        (e) => e.kind == StreamLogKind.cancel,
      );
      expect(listenEvents.length, 2);
      expect(cancelEvents.length, 2);
    });

    testWidgets(
      'Mở TaskDetailScreen trực tiếp và thoát (pop): số subscription active giảm chính xác từ 2 về 0',
      (WidgetTester tester) async {
        final task = await fakeService.createTask(
          name: 'Đồng hồ độc lập',
          colorValue: Colors.purple.toARGB32(),
        );

        expect(tracker.activeCount, 0);

        // Khởi tạo app với nút điều hướng mở TaskDetailScreen
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
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
        await tester.pump();

        expect(tracker.activeCount, 0);

        // Mở màn hình TaskDetailScreen
        await tester.tap(find.text('Mở chi tiết'));
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailScreen), findsOneWidget);

        // TaskDetailScreen lắng nghe 2 stream: tasksStream và elapsedStream(taskId)
        expect(tracker.activeCount, 2);
        expect(tracker.activeBySource['tasksStream'], 1);
        expect(tracker.activeBySource['elapsedStream:${task.id}'], 1);

        // Rời khỏi màn hình TaskDetailScreen (bằng nút Back của AppBar hoặc pop)
        final backButton = find.byType(BackButton);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
        } else {
          Navigator.of(tester.element(find.byType(TaskDetailScreen))).pop();
        }
        await tester.pumpAndSettle();

        // Màn hình chi tiết đã bị unmount
        expect(find.byType(TaskDetailScreen), findsNothing);

        // Chứng minh: toàn bộ subscription đã được hủy, activeCount trở về 0
        expect(tracker.activeCount, 0);
        expect(tracker.activeBySource, isEmpty);

        // Đối chiếu lịch sử log: có 2 sự kiện cancel tương ứng
        final detailCancels = tracker.history
            .where((e) => e.kind == StreamLogKind.cancel)
            .map((e) => e.source)
            .toList();
        expect(detailCancels, contains('tasksStream'));
        expect(detailCancels, contains('elapsedStream:${task.id}'));
      },
    );

    testWidgets(
      'Điều hướng từ HomeScreen sang TaskDetailScreen rồi quay lại: đối chiếu số subscription active từ StreamTracker',
      (WidgetTester tester) async {
        final task = await fakeService.createTask(
          name: 'Đồng hồ Flow Full',
          colorValue: Colors.teal.toARGB32(),
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

        // Ở HomeScreen:
        // - 1 subscription cho tasksStream từ StreamBuilder của HomeScreen
        // - 1 subscription cho elapsedStream từ TaskCard -> ElapsedText
        final homeActiveCount = tracker.activeCount;
        expect(homeActiveCount, greaterThanOrEqualTo(1));
        final initialTasksSubs = tracker.activeBySource['tasksStream'] ?? 0;
        final initialElapsedSubs =
            tracker.activeBySource['elapsedStream:${task.id}'] ?? 0;
        expect(initialTasksSubs, 1);
        expect(initialElapsedSubs, 1);

        // Nhấn vào card để điều hướng sang TaskDetailScreen
        await tester.tap(find.text('Đồng hồ Flow Full'));
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailScreen), findsOneWidget);

        // Khi TaskDetailScreen mở, số subscription tăng thêm 2:
        // +1 tasksStream, +1 elapsedStream(taskId)
        expect(tracker.activeCount, homeActiveCount + 2);
        expect(tracker.activeBySource['tasksStream'], initialTasksSubs + 1);
        expect(
          tracker.activeBySource['elapsedStream:${task.id}'],
          initialElapsedSubs + 1,
        );

        // Thoát khỏi TaskDetailScreen
        final backBtn = find.byType(BackButton);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        // Quay lại HomeScreen
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);

        // Chứng minh: số subscription giảm chính xác về số lượng ban đầu của HomeScreen
        expect(tracker.activeCount, homeActiveCount);
        expect(tracker.activeBySource['tasksStream'], initialTasksSubs);
        expect(
          tracker.activeBySource['elapsedStream:${task.id}'],
          initialElapsedSubs,
        );
      },
    );

    testWidgets(
      'Gỡ bỏ widget ElapsedText khỏi widget tree lập tức hủy subscription elapsedStream',
      (WidgetTester tester) async {
        final task = await fakeService.createTask(
          name: 'Đồng hồ Widget',
          colorValue: Colors.orange.toARGB32(),
        );

        bool showElapsed = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      if (showElapsed)
                        ElapsedText(
                          taskId: task.id,
                          initialElapsed: Duration.zero,
                          service: fakeService,
                        ),
                      ElevatedButton(
                        onPressed: () => setState(() => showElapsed = false),
                        child: const Text('Ẩn đồng hồ'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        // ElapsedText đang hiển thị -> activeCount = 1
        expect(find.byType(ElapsedText), findsOneWidget);
        expect(tracker.activeCount, 1);
        expect(tracker.activeBySource['elapsedStream:${task.id}'], 1);

        // Bấm nút ẩn đồng hồ -> gỡ ElapsedText khỏi widget tree
        await tester.tap(find.text('Ẩn đồng hồ'));
        await tester.pump();

        // ElapsedText unmount -> StreamBuilder hủy subscription ngay lập tức
        expect(find.byType(ElapsedText), findsNothing);
        expect(tracker.activeCount, 0);
        expect(tracker.activeBySource, isEmpty);

        // Kiểm tra StreamTracker ghi nhận log CANCEL
        final cancelLog = tracker.history.lastWhere(
          (e) => e.kind == StreamLogKind.cancel,
        );
        expect(cancelLog.source, 'elapsedStream:${task.id}');
        expect(cancelLog.activeCount, 0);
      },
    );

    testWidgets(
      'Rời hoàn toàn khỏi HomeScreen hủy toàn bộ subscription (tasksStream và card streams)',
      (WidgetTester tester) async {
        await fakeService.createTask(
          name: 'Đồng hồ A',
          colorValue: Colors.blue.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(service: fakeService),
                        ),
                      );
                    },
                    child: const Text('Vào HomeScreen'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        expect(tracker.activeCount, 0);

        // Mở HomeScreen
        await tester.tap(find.text('Vào HomeScreen'));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tracker.activeCount, greaterThan(0));

        // Rời hoàn toàn HomeScreen (pop)
        Navigator.of(tester.element(find.byType(HomeScreen))).pop();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsNothing);

        // Sau khi rời hoàn toàn HomeScreen, mọi subscription từ HomeScreen và các thẻ đều bị hủy
        expect(tracker.activeCount, 0);
        expect(tracker.activeBySource, isEmpty);
      },
    );

    testWidgets(
      'Xóa đồng hồ ở HomeScreen làm hủy subscription elapsedStream của thẻ tương ứng',
      (WidgetTester tester) async {
        final task1 = await fakeService.createTask(
          name: 'Task 1 Cần Xóa',
          colorValue: Colors.red.toARGB32(),
        );
        final task2 = await fakeService.createTask(
          name: 'Task 2 Giữ Lại',
          colorValue: Colors.green.toARGB32(),
        );

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(service: fakeService)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Task 1 Cần Xóa'), findsOneWidget);
        expect(find.text('Task 2 Giữ Lại'), findsOneWidget);

        expect(tracker.activeBySource['elapsedStream:${task1.id}'], 1);
        expect(tracker.activeBySource['elapsedStream:${task2.id}'], 1);

        // Xóa task 1 từ service
        await fakeService.deleteTask(task1.id);
        await tester.pumpAndSettle();

        expect(find.text('Task 1 Cần Xóa'), findsNothing);
        expect(find.text('Task 2 Giữ Lại'), findsOneWidget);

        // Thẻ của Task 1 đã bị gỡ bỏ, subscription của nó phải bị hủy
        expect(
          tracker.activeBySource.containsKey('elapsedStream:${task1.id}'),
          isFalse,
        );
        // Thẻ Task 2 vẫn giữ nguyên subscription
        expect(tracker.activeBySource['elapsedStream:${task2.id}'], 1);
      },
    );
  });
}
