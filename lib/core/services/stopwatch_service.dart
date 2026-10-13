import '../models/lap.dart';
import '../models/task_snapshot.dart';

// Vì sao export: UI chỉ cần import một file này là có đủ mọi kiểu trong hợp
// đồng, không phải biết cấu trúc thư mục bên trong core.
export '../models/lap.dart';
export '../models/task_snapshot.dart';
export '../models/task_status.dart';
export '../storage/task_repository.dart' show StorageException;
export 'stopwatch_exceptions.dart';

/// Hợp đồng nghiệp vụ để UI điều khiển nhiều đồng hồ chạy song song.
///
/// Vì sao là `abstract interface class`: UI chỉ phụ thuộc hợp đồng này, nên
/// đổi implementation (thật, giả lập độ trễ, mock khi test widget) không phải
/// sửa UI. `interface` cấm `extends`, buộc implementation viết đủ mọi method.
///
/// Khởi tạo: implementation tự nạp dữ liệu trong factory bất đồng bộ của
/// riêng nó, nên instance trao cho UI luôn sẵn sàng dùng. Không tồn tại trạng
/// thái "đã tạo nhưng chưa init".
///
/// Quy ước chung cho mọi method trả Future:
/// - Các lệnh được thực hiện tuần tự đúng thứ tự gọi, nên bấm nút liên tiếp
///   không bị đảo thứ tự.
/// - Lỗi luôn trả qua Future (bắt bằng `try`/`await`/`catch`), không ném
///   đồng bộ:
///   - `TaskNotFoundException`: không có đồng hồ mang `taskId`.
///   - `InvalidTransitionException`: trạng thái hiện tại không cho phép thao
///     tác (xem bảng bên dưới).
///   - `StorageException`: lưu thất bại; trạng thái giữ nguyên như trước khi
///     gọi.
///   - `ArgumentError`: tham số không hợp lệ (tên rỗng, màu ngoài ARGB 32-bit).
///   - `StateError`: gọi sau khi đã [dispose].
///
/// Bảng chuyển trạng thái hợp lệ:
/// ```text
/// idle    --start-->  running
/// running --pause-->  paused
/// paused  --resume--> running
/// running --lap-->    running   (thêm một Lap)
/// bất kỳ  --reset-->  idle      (elapsed = 0, xóa lap; idle -> idle không lỗi)
/// ```
abstract interface class StopwatchService {
  /// Danh sách đồng hồ tại lúc gọi, theo thứ tự tạo; list không sửa được.
  ///
  /// Vì sao có thêm getter đồng bộ: làm `initialData` cho StreamBuilder, để
  /// frame đầu tiên không bị trống trong lúc chờ [tasksStream] phát.
  List<TaskSnapshot> get currentTasks;

  /// Danh sách đồng hồ, phát lại mỗi khi có thay đổi.
  ///
  /// - Broadcast: nhiều widget có thể listen cùng lúc.
  /// - Mỗi listener nhận danh sách hiện tại làm sự kiện đầu tiên, sau đó nhận
  ///   bản mới sau mỗi lần tạo/xóa/đổi tên/đổi màu/start/pause/resume/reset/lap.
  /// - KHÔNG phát theo từng tick: `elapsed` trong snapshot là giá trị lúc phát.
  ///   Vì sao: tránh rebuild cả danh sách mỗi tick; ô hiển thị giờ tự lấy từ
  ///   [elapsedStream].
  /// - List phát ra không sửa được, theo thứ tự tạo.
  /// - Phát done sau khi [dispose].
  Stream<List<TaskSnapshot>> get tasksStream;

  /// Elapsed của đồng hồ [taskId], dùng để hiển thị giờ chạy liên tục.
  ///
  /// - Sự kiện đầu tiên là elapsed hiện tại, sau đó phát theo nhịp tick khi
  ///   đang chạy (nhịp do implementation quyết định). Khi pause/reset thì phát
  ///   giá trị mới một lần; không phát lặp giá trị trùng.
  /// - Listen nhiều lần hoặc nhiều nơi cùng listen đều an toàn.
  /// - Hủy subscription thì implementation phải giải phóng tài nguyên kèm theo
  ///   (không giữ Timer chạy khi không còn ai nghe).
  /// - [taskId] không tồn tại: phát `TaskNotFoundException` rồi done.
  /// - Đồng hồ bị xóa, hoặc service bị [dispose]: phát done.
  Stream<Duration> elapsedStream(String taskId);

  /// Tạo đồng hồ mới ở trạng thái idle, thêm vào cuối danh sách.
  ///
  /// [name] được trim; rỗng sau khi trim thì báo `ArgumentError`.
  /// [colorValue] là màu ARGB 32-bit.
  /// Trả về snapshot của đồng hồ mới để UI có ngay id (vd cuộn tới nó).
  Future<TaskSnapshot> createTask({
    required String name,
    required int colorValue,
  });

  /// Xóa đồng hồ, kể cả khi đang chạy; [elapsedStream] của nó phát done.
  Future<void> deleteTask(String taskId);

  /// Đổi tên; [name] được trim, rỗng sau khi trim thì báo `ArgumentError`.
  Future<void> renameTask(String taskId, String name);

  /// Đổi màu; [colorValue] là màu ARGB 32-bit.
  Future<void> changeTaskColor(String taskId, int colorValue);

  /// idle -> running.
  Future<void> start(String taskId);

  /// running -> paused, giữ nguyên elapsed và lap.
  Future<void> pause(String taskId);

  /// paused -> running, chạy tiếp từ elapsed đã có.
  Future<void> resume(String taskId);

  /// Về idle từ bất kỳ trạng thái nào: elapsed = 0 và xóa hết lap.
  Future<void> reset(String taskId);

  /// Ghi một lap khi đang running; trả về lap vừa ghi.
  Future<Lap> lap(String taskId);

  /// Dừng mọi Timer, đóng mọi StreamController và hủy mọi subscription nội bộ.
  ///
  /// - Idempotent: gọi nhiều lần, kể cả gọi đồng thời, đều trả về cùng một
  ///   Future và chỉ dọn dẹp đúng một lần.
  /// - Vì sao trả Future: cần chờ các lệnh ghi đang dở hoàn tất trước khi đóng.
  /// - Khi Future hoàn thành, [tasksStream] và mọi [elapsedStream] đã phát done.
  /// - Không tự pause đồng hồ đang chạy: dữ liệu đã lưu `runningSince`, nên lần
  ///   mở app sau giờ vẫn được tính tiếp như đồng hồ bấm giờ thật.
  Future<void> dispose();
}
