/// Helper dùng chung trong lib/core/models/: đọc JSON có kiểm tra kiểu và so
/// sánh list. Chỉ dùng nội bộ trong models, UI không cần import file này.
library;

/// Đọc `json[key]` và bảo đảm đúng kiểu [T] (cho phép [T] nullable).
///
/// Vì sao không dùng `json[key] as T`: dữ liệu đọc từ storage có thể hỏng, khi
/// đó `as` ném TypeError (là Error, không nên bắt). [FormatException] là
/// Exception nên tầng storage bắt và xử lý được.
T readField<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException(
    'Trường "$key" cần kiểu $T nhưng nhận ${value.runtimeType}.',
  );
}

/// Duration được lưu dạng số micro giây (int).
///
/// Vì sao: số nguyên giữ chính xác tuyệt đối, lưu giây dạng double sẽ sai số.
Duration readDuration(Map<String, dynamic> json, String key) =>
    Duration(microseconds: readField<int>(json, key));

/// Như [readDuration] nhưng cho phép trường vắng mặt hoặc null.
Duration? readNullableDuration(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : readDuration(json, key);

/// DateTime được lưu dạng chuỗi ISO-8601 UTC.
///
/// Vì sao: đọc được bằng mắt khi debug/export, và UTC không bị ảnh hưởng bởi
/// múi giờ hay giờ mùa hè.
DateTime readDateTime(Map<String, dynamic> json, String key) {
  final raw = readField<String>(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Trường "$key" không phải ISO-8601: "$raw".');
  }
  return parsed.toUtc();
}

/// Như [readDateTime] nhưng cho phép trường vắng mặt hoặc null.
DateTime? readNullableDateTime(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : readDateTime(json, key);

/// Enum được lưu bằng `name` (vd "running") thay vì `index`.
///
/// Vì sao: thêm/đổi thứ tự giá trị enum sau này không làm hỏng dữ liệu cũ.
T readEnum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = readField<String>(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Trường "$key" có giá trị không hợp lệ: "$name".');
}

/// Đọc một list các object JSON (vd danh sách lap).
List<Map<String, dynamic>> readObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final items = readField<List<dynamic>>(json, key);
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('Phần tử trong "$key" phải là object JSON.');
    }
    result.add(item);
  }
  return result;
}

/// So sánh hai list theo từng phần tử.
///
/// Vì sao tự viết: core là Dart thuần, không phụ thuộc `listEquals` của
/// Flutter hay package `collection`.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
