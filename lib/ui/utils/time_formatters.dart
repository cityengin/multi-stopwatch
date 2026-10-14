/// Định dạng [Duration] thành chuỗi thời gian dạng `mm:ss.cs`
/// (hoặc `hh:mm:ss.cs` nếu thời gian từ 1 giờ trở lên).
///
/// [centiseconds] là phần trăm giây (2 chữ số, từ 00 đến 99),
/// tương ứng với 10 mili-giây mỗi đơn vị.
String formatElapsed(Duration duration) {
  final microseconds = duration.inMicroseconds.abs();
  final hours = microseconds ~/ 3600000000;
  final minutes = (microseconds % 3600000000) ~/ 60000000;
  final seconds = (microseconds % 60000000) ~/ 1000000;
  final centiseconds = (microseconds % 1000000) ~/ 10000;

  final m = minutes.toString().padLeft(2, '0');
  final s = seconds.toString().padLeft(2, '0');
  final cs = centiseconds.toString().padLeft(2, '0');

  final sign = duration.isNegative ? '-' : '';

  if (hours > 0) {
    final h = hours.toString().padLeft(2, '0');
    return '$sign$h:$m:$s.$cs';
  }
  return '$sign$m:$s.$cs';
}

/// Định dạng chênh lệch thời gian delta giữa các lap (vd: `+00:01.20` hoặc `-00:00.85`).
String formatDelta(Duration? delta) {
  if (delta == null) return '--:--.--';
  final formatted = formatElapsed(delta.abs());
  if (delta == Duration.zero) return ' $formatted';
  return delta.isNegative ? '-$formatted' : '+$formatted';
}
