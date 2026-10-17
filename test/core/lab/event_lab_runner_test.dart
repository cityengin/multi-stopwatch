import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/lab/event_lab_runner.dart';
import 'package:multi_stopwatch/core/lab/lab_event.dart';

import '../support/fake_time_sources.dart';

List<(String, LabQueue)> _summary(List<LabEvent> events) => [
  for (final event in events) (event.label, event.queue),
];

void main() {
  final runner = EventLabRunner();

  group('EventLabRunner: thứ tự thực thi khớp lý thuyết', () {
    test('scheduleMicrotask chạy trước Timer.run dù đăng ký sau', () async {
      expect(_summary(await runner.run(LabScenario.microtaskVsTimer)), [
        ('sync: start', LabQueue.sync),
        ('sync: end', LabQueue.sync),
        ('scheduleMicrotask', LabQueue.microtask),
        ('Timer.run', LabQueue.event),
      ]);
    });

    test('Future.sync chạy ngay; Future.microtask và then là microtask; '
        'Future() là event', () async {
      expect(_summary(await runner.run(LabScenario.futureConstructors)), [
        ('sync: start', LabQueue.sync),
        ('Future.sync', LabQueue.sync),
        ('sync: end', LabQueue.sync),
        ('Future.microtask', LabQueue.microtask),
        ('Future.value().then', LabQueue.microtask),
        ('Future()', LabQueue.event),
      ]);
    });

    test('Future.delayed(Duration.zero) vào hàng đợi event, sau microtask và '
        'theo thứ tự đăng ký với Timer khác', () async {
      expect(_summary(await runner.run(LabScenario.delayedZero)), [
        ('sync: start', LabQueue.sync),
        ('sync: end', LabQueue.sync),
        ('scheduleMicrotask', LabQueue.microtask),
        ('Timer.run #1', LabQueue.event),
        ('Future.delayed(zero)', LabQueue.event),
        ('Timer.run #2', LabQueue.event),
      ]);
    });

    test('hàm async chạy đồng bộ tới await; phần sau await một Future đã xong '
        'là microtask', () async {
      expect(_summary(await runner.run(LabScenario.awaitCompletedFuture)), [
        ('sync: call worker()', LabQueue.sync),
        ('worker: before await', LabQueue.sync),
        ('sync: end', LabQueue.sync),
        ('worker: after await', LabQueue.microtask),
        ('scheduleMicrotask', LabQueue.microtask),
      ]);
    });

    test('async gap: code khác chen vào và đổi trạng thái trong lúc await; '
        'phần sau await chạy trong lượt event hoàn thành Future', () async {
      expect(_summary(await runner.run(LabScenario.asyncGap)), [
        ('worker: counter = 0, await Future.delayed(zero)', LabQueue.sync),
        ('sync: worker is waiting, caller continues', LabQueue.sync),
        ('microtask: counter = 1', LabQueue.microtask),
        ('worker: after await, counter = 1', LabQueue.event),
        ('Timer.run: counter = 2', LabQueue.event),
      ]);
    });

    test(
      'microtask sinh ra trong lúc xả hàng đợi vẫn chạy trước Timer',
      () async {
        expect(_summary(await runner.run(LabScenario.nestedMicrotasks)), [
          ('sync: end', LabQueue.sync),
          ('microtask 1: schedules microtask 2', LabQueue.microtask),
          ('microtask 2', LabQueue.microtask),
          ('Timer.run', LabQueue.event),
        ]);
      },
    );
  });

  group('EventLabRunner', () {
    test('mọi kịch bản có tiêu đề và giải thích; sequence liên tục từ 1; '
        'thời điểm không giảm; kết quả không sửa được', () async {
      for (final scenario in LabScenario.values) {
        final events = await runner.run(scenario);

        expect(scenario.title, isNotEmpty, reason: scenario.name);
        expect(scenario.explanation, isNotEmpty, reason: scenario.name);
        expect(events.map((e) => e.sequence), [
          for (var i = 1; i <= events.length; i++) i,
        ], reason: scenario.name);
        for (var i = 1; i < events.length; i++) {
          expect(events[i].at >= events[i - 1].at, isTrue);
        }
        expect(() => events.add(events.first), throwsUnsupportedError);
      }
    });

    test('runAll chạy mọi kịch bản theo thứ tự khai báo, kết quả giống chạy '
        'riêng', () async {
      final all = await runner.runAll();

      expect(all.keys, LabScenario.values);
      for (final scenario in LabScenario.values) {
        expect(
          _summary(all[scenario]!),
          _summary(await runner.run(scenario)),
          reason: scenario.name,
        );
      }
    });

    test('chạy nhiều kịch bản đồng thời không lẫn sự kiện của nhau', () async {
      final together = await Future.wait([
        for (final scenario in LabScenario.values) runner.run(scenario),
      ]);

      for (var i = 0; i < LabScenario.values.length; i++) {
        expect(
          _summary(together[i]),
          _summary(await runner.run(LabScenario.values[i])),
          reason: LabScenario.values[i].name,
        );
      }
    });

    test('LabEvent so sánh theo giá trị và có toString dễ đọc', () {
      const event = LabEvent(
        sequence: 1,
        label: 'Timer.run',
        queue: LabQueue.event,
        at: Duration(milliseconds: 2),
      );
      const same = LabEvent(
        sequence: 1,
        label: 'Timer.run',
        queue: LabQueue.event,
        at: Duration(milliseconds: 2),
      );

      expect(event, same);
      expect(event.hashCode, same.hashCode);
      expect(
        event,
        isNot(
          const LabEvent(
            sequence: 2,
            label: 'Timer.run',
            queue: LabQueue.event,
            at: Duration(milliseconds: 2),
          ),
        ),
      );
      expect(event.toString(), allOf(contains('#1'), contains('[event]')));
    });

    test('thời điểm lấy từ TimeSource được inject', () async {
      final events = await EventLabRunner(timeSource: ManualTimeSource())
          .run(LabScenario.delayedZero);

      expect(events.map((e) => e.at), everyElement(Duration.zero));
    });
  });
}
