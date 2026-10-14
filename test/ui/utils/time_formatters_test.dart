import 'package:flutter_test/flutter_test.dart';
import 'package:multi_stopwatch/ui/utils/time_formatters.dart';

void main() {
  group('Time Formatters Tests', () {
    test('formatElapsed định dạng mm:ss.cs cho thời gian dưới 1 giờ', () {
      expect(formatElapsed(Duration.zero), '00:00.00');
      expect(
        formatElapsed(const Duration(seconds: 5, milliseconds: 40)),
        '00:05.04',
      );
      expect(
        formatElapsed(const Duration(minutes: 12, seconds: 34, milliseconds: 560)),
        '12:34.56',
      );
      expect(
        formatElapsed(const Duration(minutes: 59, seconds: 59, milliseconds: 990)),
        '59:59.99',
      );
    });

    test('formatElapsed định dạng hh:mm:ss.cs cho thời gian từ 1 giờ trở lên', () {
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 450)),
        '01:02:03.45',
      );
      expect(
        formatElapsed(const Duration(hours: 10, minutes: 0, seconds: 0, milliseconds: 0)),
        '10:00:00.00',
      );
    });

    test('formatDelta hiển thị đúng dấu cộng/trừ và giá trị null', () {
      expect(formatDelta(null), '--:--.--');
      expect(
        formatDelta(const Duration(seconds: 1, milliseconds: 200)),
        '+00:01.20',
      );
      expect(
        formatDelta(const Duration(seconds: -1, milliseconds: -200)),
        '-00:01.20',
      );
      expect(formatDelta(Duration.zero), ' 00:00.00');
    });
  });
}
