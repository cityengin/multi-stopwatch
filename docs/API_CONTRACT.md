# API Contract: lib/core cho người làm UI

Tài liệu này mô tả phần business logic (`lib/core/`) mà UI dùng: cách khởi tạo, các stream, các lệnh, lỗi và mấy lớp hỗ trợ màn Debug/Lab. UI chỉ cần phụ thuộc interface `StopwatchService`; mọi chi tiết bên trong có thể đổi mà không ảnh hưởng UI.

Cần thêm hoặc đổi API thì báo người làm core, không sửa trực tiếp trong `lib/core/`.

## 1. Import

| Cần gì | Import |
|---|---|
| Hợp đồng, models, lỗi (`StopwatchService`, `TaskSnapshot`, `Lap`, `TaskStatus`, `StopwatchException`, `TaskNotFoundException`, `InvalidTransitionException`, `StorageException`) | `package:multi_stopwatch/core/services/stopwatch_service.dart` |
| Tạo service | `package:multi_stopwatch/core/services/stopwatch_manager.dart` |
| Lưu trên máy | `package:multi_stopwatch/core/storage/local_task_repository.dart` |
| API giả lập (độ trễ, lỗi) | `package:multi_stopwatch/core/storage/in_memory_task_repository.dart` |
| Tự thử lại khi lỗi | `package:multi_stopwatch/core/storage/retrying_task_repository.dart` |
| Throttle / debounce | `package:multi_stopwatch/core/transformers/rate_limit.dart` |
| Màn Debug | `package:multi_stopwatch/core/debug/stream_tracker.dart` |
| Màn Lab | `package:multi_stopwatch/core/lab/event_lab_runner.dart` và `package:multi_stopwatch/core/lab/lab_event.dart` |

`stopwatch_service.dart` đã export sẵn models và các lỗi, nên màn hình thường chỉ cần import file này.

## 2. Khởi tạo StopwatchManager

`StopwatchManager` là implementation của `StopwatchService`. Cách tạo chuẩn là `StopwatchManager.open(...)`: nó nạp dữ liệu từ repository xong rồi mới trả về, nên service nhận được luôn dùng ngay được (không có bước `init()`).

```dart
static Future<StopwatchManager> open({
  required TaskRepository repository,
  TickSource? tickSource,   // bỏ trống: manager tự tạo và tự dispose
  TimeSource? timeSource,   // bỏ trống: giờ hệ thống thật
  StreamTracker? tracker,   // tùy chọn, cho màn Debug
});
```

Nếu đọc dữ liệu thất bại (vd dữ liệu đã lưu bị hỏng), Future của `open` lỗi với `StorageException`, nên hãy hiển thị lỗi thay vì màn hình trống.

### 2.1. Lưu trên máy: LocalTaskRepository (shared_preferences)

Dùng cho app thật: dữ liệu còn nguyên sau khi tắt/mở app, đồng hồ đang chạy được tính tiếp cả thời gian app bị tắt.

```dart
import 'package:flutter/widgets.dart';
import 'package:multi_stopwatch/core/services/stopwatch_manager.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';
import 'package:multi_stopwatch/core/storage/local_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // bắt buộc trước khi dùng plugin
  final preferences = await SharedPreferences.getInstance();
  final StopwatchService service = await StopwatchManager.open(
    repository: LocalTaskRepository(preferences),
  );
  runApp(MyApp(service: service));
}
```

- `LocalTaskRepository(preferences, {String key = LocalTaskRepository.defaultKey})`: đổi `key` nếu muốn tách dữ liệu nhiều hồ sơ.
- Dữ liệu nằm dưới một key duy nhất (`multi_stopwatch.tasks`) dạng JSON `{"version": 1, "tasks": [...]}`.
- Dữ liệu hỏng: `open` báo `StorageException`, dữ liệu cũ không bị ghi đè.

### 2.2. API giả lập: InMemoryTaskRepository

Dùng để demo độ trễ mạng, lỗi và retry, hoặc khi test widget. Dữ liệu chỉ nằm trong bộ nhớ, mất khi tắt app.

```dart
import 'package:multi_stopwatch/core/services/stopwatch_manager.dart';
import 'package:multi_stopwatch/core/services/stopwatch_service.dart';
import 'package:multi_stopwatch/core/storage/in_memory_task_repository.dart';
import 'package:multi_stopwatch/core/storage/retrying_task_repository.dart';

Future<StopwatchService> openDemoService() async {
  final api = InMemoryTaskRepository(
    latency: const Duration(milliseconds: 300), // mỗi request chờ 300ms
    failureRate: 0.2,                           // 20% request lỗi
  );
  return StopwatchManager.open(
    repository: RetryingTaskRepository(api), // tối đa 3 lần gọi (2 lần thử lại)
  );
}
```

Tham số của `InMemoryTaskRepository`:

| Tham số / thành viên | Ý nghĩa |
|---|---|
| `initial` | Danh sách `StopwatchTask` có sẵn trên "server" |
| `latency` | Độ trễ mỗi lần gọi; đổi được lúc đang chạy |
| `failureRate` | Xác suất lỗi 0..1 mỗi lần gọi; `1` là mất mạng hoàn toàn; đổi được lúc đang chạy |
| `random` | Truyền `Random(seed)` để chuỗi lỗi lặp lại được |
| `failNext([count])` | Buộc `count` lần gọi kế tiếp lỗi |

Không cần lỗi hay retry thì chỉ cần `StopwatchManager.open(repository: InMemoryTaskRepository())`.

`RetryingTaskRepository(inner, {maxAttempts = 3, initialDelay = 200ms, onRetry})` thử lại khi gặp `StorageException`, chờ 200ms, 400ms... giữa các lần. `maxAttempts` tính cả lần gọi đầu. `onRetry(nextAttempt, error)` có thể dùng để hiện "đang thử lại lần 2" trên màn Debug. Hết lượt thử thì lệnh mới báo lỗi.

### 2.3. Khi đã có sẵn dữ liệu: constructor

`open` thực chất là `loadAll()` rồi gọi constructor. Nếu đã nạp dữ liệu ở chỗ khác, có thể gọi constructor trực tiếp (đồng bộ):

```dart
final service = StopwatchManager(
  repository: repository,
  initialTasks: await repository.loadAll(),
);
```

### 2.4. Kết thúc

Gọi `await service.dispose()` khi app đóng (vd trong `dispose()` của widget gốc). Gọi nhiều lần không sao. `dispose` không pause đồng hồ đang chạy: lần mở app sau, giờ vẫn được tính tiếp.

## 3. Dữ liệu UI nhận được

### TaskSnapshot: ảnh chụp một đồng hồ

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `id` | `String` | Định danh, không đổi |
| `name` | `String` | Đã trim |
| `colorValue` | `int` | Màu ARGB 32-bit; hiển thị bằng `Color(snapshot.colorValue)` |
| `createdAt` | `DateTime` | UTC; hiển thị thì dùng `.toLocal()` |
| `status` | `TaskStatus` | `idle`, `running`, `paused` |
| `elapsed` | `Duration` | Giá trị **tại lúc chụp**; muốn giờ chạy liên tục thì dùng `elapsedStream` |
| `laps` | `List<Lap>` | Theo thứ tự bấm (lap 1 đứng đầu), không sửa được |

### Lap

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `number` | `int` | Bắt đầu từ 1 |
| `split` | `Duration` | Lap time: thời gian từ lap trước (lap 1 thì tính từ lúc bắt đầu) |
| `total` | `Duration` | Tổng elapsed lúc bấm lap |
| `delta` | `Duration?` | `split` trừ split của lap trước: **âm là nhanh hơn**, dương là chậm hơn; `null` với lap 1 |
| `recordedAt` | `DateTime` | UTC |

Mọi model đều immutable, so sánh `==` theo giá trị.

## 4. Stream

| | `tasksStream` | `elapsedStream(taskId)` |
|---|---|---|
| Kiểu | `Stream<List<TaskSnapshot>>` | `Stream<Duration>` |
| Broadcast / nhiều nơi listen | Có | Có |
| Sự kiện đầu tiên | Danh sách hiện tại | Elapsed hiện tại |
| Phát khi nào | Sau mỗi lần tạo/xóa/đổi tên/đổi màu/start/pause/resume/reset/lap; đúng một lần cho mỗi thao tác hàng loạt (mục 5.1) | Mỗi tick (~33ms) khi đang chạy; một lần khi pause/reset |
| Phát theo tick? | **Không** | Có, chỉ khi đồng hồ đang chạy |
| Giá trị trùng | — | Không phát lặp |
| Kết thúc (done) | Sau `dispose()` | Khi đồng hồ bị xóa hoặc sau `dispose()` |
| Lỗi | — | `taskId` không tồn tại: phát `TaskNotFoundException` rồi done |

`currentTasks` (getter đồng bộ) trả về danh sách lúc gọi, dùng làm `initialData` để frame đầu không trống.

### Cách dùng gợi ý

Danh sách: rebuild khi trạng thái đổi, không rebuild mỗi tick.

```dart
StreamBuilder<List<TaskSnapshot>>(
  stream: service.tasksStream,
  initialData: service.currentTasks,
  builder: (context, snapshot) {
    final tasks = snapshot.data ?? const <TaskSnapshot>[];
    return ListView(children: [for (final task in tasks) TaskTile(task: task)]);
  },
);
```

Ô hiển thị giờ: chỉ ô này rebuild mỗi tick. **Tạo stream một lần** (vd trong `initState`), không gọi `elapsedStream(...)` ngay trong `build`; mỗi lần gọi trả về một stream mới, nên `StreamBuilder` sẽ hủy và listen lại sau mỗi lần rebuild.

```dart
class _ElapsedTextState extends State<ElapsedText> {
  late final Stream<Duration> _elapsed = widget.service.elapsedStream(widget.task.id);

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: _elapsed,
    initialData: widget.task.elapsed,
    builder: (context, snapshot) => Text('${snapshot.data}'),
  );
}
```

Hủy subscription (widget bị gỡ) thì core tự dừng nghe tick; không còn ai nghe đồng hồ nào đang chạy thì Timer cũng tự tắt. Đồng hồ vẫn chạy đúng giờ vì thời gian tính theo mốc chứ không theo tick.

App xuống nền hay máy ngủ: không cần gọi gì thêm, lần đọc kế tiếp tự bù phần thời gian đã trôi.

## 5. Lệnh

Mọi lệnh trả `Future`; **lỗi luôn trả qua Future**, không ném đồng bộ. Các lệnh chạy tuần tự đúng thứ tự gọi, nên bấm liên tiếp không bị đảo thứ tự.

| Lệnh | Trả về | Ghi chú |
|---|---|---|
| `createTask(name:, colorValue:)` | `Future<TaskSnapshot>` | Tạo ở trạng thái idle, thêm vào cuối danh sách |
| `deleteTask(id)` | `Future<void>` | Xóa được cả khi đang chạy |
| `renameTask(id, name)` | `Future<void>` | |
| `changeTaskColor(id, colorValue)` | `Future<void>` | |
| `start(id)` | `Future<void>` | idle → running |
| `pause(id)` | `Future<void>` | running → paused |
| `resume(id)` | `Future<void>` | paused → running |
| `reset(id)` | `Future<void>` | Về idle, elapsed = 0, xóa lap; đang idle thì không làm gì |
| `lap(id)` | `Future<Lap>` | Chỉ khi running; trả về lap vừa ghi |
| `runAll()` | `Future<void>` | Hàng loạt: idle thì start, paused thì resume (mục 5.1) |
| `pauseAll()` | `Future<void>` | Hàng loạt: pause mọi đồng hồ running (mục 5.1) |
| `resetAll()` | `Future<void>` | Hàng loạt: mọi đồng hồ về 00:00, xóa lap (mục 5.1) |
| `deleteAll()` | `Future<void>` | Hàng loạt: xóa mọi đồng hồ (mục 5.1) |
| `dispose()` | `Future<void>` | Xem mục 2.4 |

Bật/tắt nút theo `status`:

| `status` | Nút hợp lệ |
|---|---|
| `idle` | Start |
| `running` | Pause, Lap, Reset |
| `paused` | Resume, Reset |

Thời điểm UI thấy thay đổi:
- `start`, `pause`, `resume`, `reset`, `lap`, `renameTask`, `changeTaskColor`: stream phát **ngay**, rồi mới lưu. Lưu lỗi thì trạng thái được hoàn tác và stream phát lại trạng thái cũ.
- `createTask`, `deleteTask`: chờ lưu xong mới phát. Với repository có độ trễ, nên hiện loading trong lúc chờ Future.

### 5.1. Thao tác hàng loạt

| Lệnh | Tác động lên | Bỏ qua | Kết quả |
|---|---|---|---|
| `runAll()` | idle, paused | running | Tất cả thành running; đồng hồ paused chạy tiếp từ elapsed đã có |
| `pauseAll()` | running | idle, paused | Thành paused, giữ elapsed và lap |
| `resetAll()` | running, paused | idle (vốn đã ở 0) | Thành idle, elapsed = 0, xóa hết lap (giống `reset`) |
| `deleteAll()` | mọi đồng hồ | — | Danh sách rỗng; `elapsedStream` của từng đồng hồ phát done |

Quy ước chung:
- **Một mốc thời gian cho cả lô:** các đồng hồ cùng một lần bấm "Chạy tất cả" có cùng thời điểm bắt đầu, "Dừng tất cả" dừng ở cùng thời điểm.
- **`tasksStream` phát đúng một lần** sau khi cả lô đã áp dụng, không phát riêng cho từng đồng hồ. UI không bao giờ thấy "nửa lô".
- **Ghi lưu trữ một lần** cho cả lô; cả lô cùng được lưu hoặc cùng không.
- **Không có đồng hồ nào thuộc phạm vi thì không làm gì:** không phát, không ghi, Future vẫn hoàn thành bình thường.
- **Thời điểm UI thấy thay đổi** giống lệnh đơn lẻ: `runAll`, `pauseAll`, `resetAll` phát ngay rồi mới lưu, lưu lỗi thì cả lô được hoàn tác và `tasksStream` phát lại trạng thái cũ một lần. `deleteAll` chờ lưu xong mới phát; lưu lỗi thì không đồng hồ nào bị xóa.
- **Lỗi:** `StorageException` như trên; gọi sau `dispose()` thì `StateError`.

Bật/tắt nút hàng loạt: tính từ danh sách mới nhất của `tasksStream` (hoặc `currentTasks`), không cần tự đếm:

```dart
final tasks = snapshot.data ?? const <TaskSnapshot>[];
final canRunAll = tasks.any((t) => t.status != TaskStatus.running);
final canPauseAll = tasks.any((t) => t.status == TaskStatus.running);
final canResetAll = tasks.any((t) => t.status != TaskStatus.idle);
final canDeleteAll = tasks.isNotEmpty;
```

Vì mỗi lệnh hàng loạt chỉ phát một lần, các nút này đổi trạng thái đúng một lần sau mỗi lần bấm.

## 6. Lỗi

| Lỗi | Khi nào |
|---|---|
| `TaskNotFoundException` (`taskId`) | Không có đồng hồ mang id đó (vd vừa bị xóa) |
| `InvalidTransitionException` (`taskId`, `action`, `status`) | Thao tác không hợp lệ với trạng thái hiện tại (vd pause khi idle) |
| `StorageException` (`message`, `cause`) | Đọc/ghi thất bại; trạng thái đã được hoàn tác |
| `ArgumentError` | Tên rỗng sau khi trim, hoặc màu ngoài 0..0xFFFFFFFF |
| `StateError` | Gọi lệnh sau `dispose()` |

`TaskNotFoundException` và `InvalidTransitionException` cùng là lớp con của `sealed class StopwatchException`, nên `switch` được kiểm tra đủ trường hợp:

```dart
try {
  await service.pause(task.id);
} on StopwatchException catch (error) {
  final message = switch (error) {
    TaskNotFoundException() => 'Đồng hồ không còn tồn tại',
    InvalidTransitionException(:final action) => 'Không thể $action lúc này',
  };
  showError(message);
} on StorageException {
  showError('Không lưu được, đã hoàn tác');
}
```

## 7. Throttle và debounce (rate_limit.dart)

| | Cách dùng | Hành vi |
|---|---|---|
| Throttle | `stream.throttled(duration, trailing: false)` | Phát ngay sự kiện đầu, bỏ các sự kiện trong `duration` kế tiếp. `trailing: true` thì sự kiện cuối trong cửa sổ được phát khi cửa sổ đóng |
| Debounce | `stream.debounced(duration)` | Chỉ phát sự kiện cuối khi nguồn đã im lặng đủ `duration` |

Có thể dùng dạng class: `ThrottleTransformer(duration, trailing: ...)`, `DebounceTransformer(duration)` với `stream.transform(...)`. Cả hai giữ nguyên tính broadcast của stream nguồn, chuyển lỗi đi ngay, và khi nguồn done thì phát nốt sự kiện đang chờ.

Gợi ý:
- Danh sách nhiều đồng hồ chỉ cần cập nhật mỗi giây: `service.elapsedStream(id).throttled(const Duration(seconds: 1), trailing: true)`. Phải có `trailing: true` để không mất giá trị cuối lúc pause.
- Ô đổi tên: đẩy text vào một `StreamController<String>`, rồi `controller.stream.debounced(const Duration(milliseconds: 500)).listen((name) => service.renameTask(id, name))`. Như vậy không lưu theo từng phím; nhớ hủy subscription và đóng controller khi widget bị gỡ.
- Không debounce stream tick: nguồn phát liên tục nên debounce sẽ không bao giờ phát.

## 8. Màn Debug: StreamTracker

Tạo một `StreamTracker` và truyền vào `open(..., tracker: tracker)`. Manager truyền tiếp nó cho `TickSource` tự tạo. Manager **không** dispose tracker; nơi tạo tự gọi `tracker.dispose()`.

```dart
final tracker = StreamTracker(historyLimit: 200);
final service = await StopwatchManager.open(
  repository: LocalTaskRepository(preferences),
  tracker: tracker,
);
```

| Thành viên | Ý nghĩa |
|---|---|
| `activeCount` | Tổng số subscription đang hoạt động |
| `activeBySource` | `Map<String, int>` theo từng luồng; luồng về 0 thì biến mất khỏi map |
| `events` | `Stream<StreamLogEvent>` broadcast, phát sự kiện mới |
| `history` | `List<StreamLogEvent>`, tối đa `historyLimit` sự kiện gần nhất, cũ trước mới sau |
| `dispose()` | Đóng `events`; gọi nhiều lần không sao |

`StreamLogEvent` gồm `kind` (`StreamLogKind.listen`, `cancel`, `done`, `dispose`), `source`, `activeCount` (tổng sau sự kiện) và `at` (UTC).

Tên `source` xuất hiện trong log:

| `source` | Là gì |
|---|---|
| `tasksStream` | Subscription của `service.tasksStream` |
| `elapsedStream:<taskId>` | Subscription của `service.elapsedStream(taskId)` |
| `TickSource.ticks` | Đồng hồ đang chạy và có người nghe thì core nghe tick, mỗi đồng hồ một subscription |
| `TickSource`, `StopwatchManager` | Sự kiện `dispose` của thành phần đó |

Sau `service.dispose()`, `activeCount` về 0 và log kết thúc bằng `dispose TickSource` rồi `dispose StopwatchManager`. Ngoại lệ: listener đang pause chỉ nhận done (và được trừ khỏi số đếm) khi resume.

## 9. Màn Lab: EventLabRunner

Chạy thật các kịch bản event loop và trả về thứ tự thực thi đo được.

```dart
final runner = EventLabRunner();
final List<LabEvent> events = await runner.run(LabScenario.asyncGap);
final all = await runner.runAll(); // Map<LabScenario, List<LabEvent>>, theo thứ tự khai báo
```

| Kịch bản (`LabScenario`) | Minh họa |
|---|---|
| `microtaskVsTimer` | `scheduleMicrotask` chạy trước `Timer.run` |
| `futureConstructors` | `Future()`, `Future.microtask`, `Future.value().then`, `Future.sync` |
| `delayedZero` | `Future.delayed(Duration.zero)` không chạy ngay |
| `awaitCompletedFuture` | Hàm async chạy đồng bộ tới `await`; phần sau `await` một Future đã xong là microtask |
| `asyncGap` | Code khác chen vào và đổi trạng thái trong lúc `await` |
| `nestedMicrotasks` | Microtask sinh thêm microtask vẫn chạy trước Timer |

Mỗi kịch bản có `title` và `explanation` (tiếng Anh, khớp với giao diện) để hiển thị. Mỗi `LabEvent` gồm `sequence` (thứ tự, từ 1), `label`, `queue` (`LabQueue.sync`, `microtask`, `event`: đo bằng Zone lúc chạy, không ghi tay) và `at` (thời gian tính từ lúc kịch bản bắt đầu). Kết quả không sửa được; chạy nhiều kịch bản cùng lúc không lẫn nhau.

## 10. Lớp cấp thấp (UI thường không cần)

| Lớp | Vai trò |
|---|---|
| `TaskRepository` | Interface lưu trữ (`loadAll`, `upsert`, `delete`, và ghi hàng loạt `upsertAll`, `deleteAll` trong một lần ghi); mọi thao tác idempotent |
| `StopwatchTask` | Dạng lưu trữ của một đồng hồ (`accumulated`, `runningSince`...) |
| `TickSource` | Nguồn tick dùng chung (`interval` mặc định 33ms); Timer chỉ chạy khi có người nghe |
| `ElapsedTracker` | Tính elapsed theo mốc thời gian, bù thời gian máy ngủ, khôi phục sau restart |
| `TimeSource`, `SystemTimeSource` | Nguồn thời gian; truyền `timeSource:` vào `open` để điều khiển thời gian trong widget test |

## 11. Hạn chế đã biết

- Người dùng chỉnh giờ hệ thống **tiến** khi đồng hồ đang chạy: phần chênh bị cộng vào elapsed (core không phân biệt được với lúc máy ngủ).
- Người dùng chỉnh giờ hệ thống **lùi** khi đồng hồ đang chạy: elapsed trong phiên vẫn đúng, nhưng mốc đã hiệu chỉnh chỉ được lưu ở lệnh kế tiếp của đồng hồ đó; nếu app bị tắt trước lệnh đó thì lần mở sau tính thiếu.
- Listener đang pause lúc `dispose()` chỉ nhận done khi được resume.
