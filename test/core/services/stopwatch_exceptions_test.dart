import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';

String _kind(StopwatchException error) => switch (error) {
  TaskNotFoundException() => 'notFound',
  InvalidTransitionException() => 'invalid',
};

void main() {
  group('lỗi trong hợp đồng StopwatchService', () {
    test('TaskNotFoundException và InvalidTransitionException có message và '
        'toString dễ đọc; switch trên lớp sealed đủ mọi trường hợp', () {
      final notFound = TaskNotFoundException('t1');
      final invalid = InvalidTransitionException(
        taskId: 't1',
        action: 'pause',
        status: TaskStatus.idle,
      );

      expect(
        notFound.toString(),
        'TaskNotFoundException: Không tìm thấy đồng hồ "t1".',
      );
      expect(
        invalid.toString(),
        'InvalidTransitionException: Không thể pause đồng hồ "t1" khi đang idle.',
      );
      expect([_kind(notFound), _kind(invalid)], ['notFound', 'invalid']);
    });

    test('StorageException ghi kèm nguyên nhân khi có', () {
      const cause = FormatException('hỏng');

      expect(
        StorageException('Lỗi ghi').toString(),
        'StorageException: Lỗi ghi',
      );
      expect(
        StorageException('Lỗi đọc', cause: cause).toString(),
        allOf(contains('Lỗi đọc'), contains('cause'), contains('hỏng')),
      );
    });
  });
}
