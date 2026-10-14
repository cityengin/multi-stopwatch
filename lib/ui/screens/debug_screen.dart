import 'package:flutter/material.dart';

import '../../core/debug/stream_tracker.dart';
import '../scope/stopwatch_scope.dart';

/// Màn hình Debug theo dõi các luồng Stream và Subscription trong ứng dụng.
///
/// Mục đích:
/// - Hiển thị số lượng subscription đang hoạt động theo thời gian thực ([StreamTracker.activeCount]).
/// - Phân rã số subscription theo từng luồng ([StreamTracker.activeBySource]).
/// - Hiển thị dòng thời gian log các sự kiện `listen`, `cancel`, `done`, `dispose`.
/// - Giúp giảng viên và nhóm kiểm chứng trực quan việc hủy subscription khi thoát màn hình,
///   đảm bảo không xảy ra rò rỉ bộ nhớ (memory leak).
/// - Thoát khỏi màn hình này sẽ tự động hủy subscription lắng nghe tracker events.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key, this.tracker});

  final StreamTracker? tracker;

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  StreamTracker? _cachedTracker;
  Stream<StreamLogEvent>? _eventsStream;
  StreamLogKind? _selectedFilter;

  StreamTracker? get _tracker => _cachedTracker;

  @override
  void initState() {
    super.initState();
    if (widget.tracker != null) {
      _cachedTracker = widget.tracker;
      _initStream(_cachedTracker!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_eventsStream == null) {
      _cachedTracker = widget.tracker ?? StopwatchScope.trackerOf(context);
      if (_cachedTracker != null) {
        _initStream(_cachedTracker!);
      }
    }
  }

  void _initStream(StreamTracker tracker) {
    // Stream lấy một lần duy nhất trong initState/didChangeDependencies
    _eventsStream = tracker.events;
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    final ms = local.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  (Color, IconData, String) _getKindDetails(StreamLogKind kind) {
    return switch (kind) {
      StreamLogKind.listen => (
        Colors.green.shade700,
        Icons.play_circle_outline,
        'LISTEN',
      ),
      StreamLogKind.cancel => (
        Colors.orange.shade800,
        Icons.cancel_outlined,
        'CANCEL',
      ),
      StreamLogKind.done => (
        Colors.purple.shade700,
        Icons.check_circle_outline,
        'DONE',
      ),
      StreamLogKind.dispose => (
        Colors.blueGrey.shade700,
        Icons.delete_sweep_outlined,
        'DISPOSE',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracker = _tracker;

    if (tracker == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stream Debugger')),
        body: const Center(
          child: Text(
            'StreamTracker not found.\nPlease make sure StopwatchScope was provided with a tracker.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Tracker (Debug)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<StreamLogEvent>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          final activeCount = tracker.activeCount;
          final activeBySource = tracker.activeBySource;
          final history = tracker.history.toList();

          // Lọc danh sách theo kind nếu có filter
          final filteredHistory = _selectedFilter == null
              ? history
              : history.where((e) => e.kind == _selectedFilter).toList();

          // Sắp xếp sự kiện mới nhất lên đầu danh sách để dễ theo dõi
          final displayLogs = filteredHistory.reversed.toList();

          return Column(
            children: [
              // 1. Thẻ tổng quan số lượng subscription đang chạy
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    120,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: activeCount > 0
                          ? Colors.indigo.shade300
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Subscriptions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tracked via StreamTracker',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              key: const Key('active_subscriptions_badge'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: activeCount > 0
                                    ? Colors.indigo.shade700
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$activeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (activeBySource.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Active streams breakdown:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: activeBySource.entries.map((entry) {
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade900,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Mẹo demo chứng minh cho thầy
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo: Opening detail increases subscriptions. Leaving detail logs '
                        'CANCEL event and decreases subscriptions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Thanh bộ lọc Kind (All, Listen, Cancel, Done, Dispose)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedFilter == null,
                      onSelected: (_) => setState(() => _selectedFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...StreamLogKind.values.map((kind) {
                      final isSelected = _selectedFilter == kind;
                      final (_, _, label) = _getKindDetails(kind);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => setState(() {
                            _selectedFilter = isSelected ? null : kind;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // 4. Danh sách log sự kiện
              Expanded(
                child: displayLogs.isEmpty
                    ? Center(
                        child: Text(
                          'No events recorded in log yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('stream_logs_list'),
                        itemCount: displayLogs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = displayLogs[index];
                          final (kindColor, kindIcon, kindLabel) =
                              _getKindDetails(event.kind);

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: kindColor.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(kindIcon, color: kindColor, size: 20),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kindColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    kindLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    event.source,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Time: ${_formatTimestamp(event.at)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active: ${event.activeCount}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
