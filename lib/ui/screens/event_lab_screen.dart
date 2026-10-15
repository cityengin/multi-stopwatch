import 'package:flutter/material.dart';

import '../../core/lab/event_lab_runner.dart';
import '../../core/lab/lab_event.dart';

/// Màn hình Event Loop Lab: chạy thực tế các kịch bản bất đồng bộ của Dart
/// và đo đạc thứ tự thực thi thực tế (Sync -> Microtask -> Event).
///
/// Phục vụ minh họa trực quan và trả lời câu hỏi vấn đáp:
/// 1. Mã đồng bộ chạy hết trên Call Stack trước.
/// 2. Event loop xả sạch toàn bộ hàng đợi Microtask.
/// 3. Event loop lấy 1 sự kiện từ Event Queue (Timer, I/O), rồi lại kiểm tra Microtask.
class EventLabScreen extends StatefulWidget {
  const EventLabScreen({super.key, this.runner});

  final EventLabRunner? runner;

  @override
  State<EventLabScreen> createState() => _EventLabScreenState();
}

class _EventLabScreenState extends State<EventLabScreen> {
  late final EventLabRunner _runner = widget.runner ?? EventLabRunner();

  LabScenario _selectedScenario = LabScenario.microtaskVsTimer;
  Map<LabScenario, List<LabEvent>> _results = {};
  bool _isRunning = false;

  Future<void> _runCurrent() async {
    setState(() => _isRunning = true);
    try {
      final events = await _runner.run(_selectedScenario);
      if (!mounted) return;
      setState(() {
        _results = Map.from(_results)..[_selectedScenario] = events;
      });
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  Future<void> _runAll() async {
    setState(() => _isRunning = true);
    try {
      final all = await _runner.runAll();
      if (!mounted) return;
      setState(() {
        _results = all;
      });
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  void _clearResults() {
    setState(() {
      _results = {};
    });
  }

  (Color, IconData, String) _getQueueDetails(LabQueue queue) {
    return switch (queue) {
      LabQueue.sync => (Colors.teal.shade700, Icons.flash_on, 'SYNC'),
      LabQueue.microtask => (Colors.orange.shade800, Icons.bolt, 'MICROTASK'),
      LabQueue.event => (Colors.purple.shade700, Icons.schedule, 'EVENT'),
    };
  }

  String _formatDuration(Duration d) {
    if (d.inMicroseconds < 1000) {
      return '+${d.inMicroseconds} µs';
    }
    return '+${(d.inMicroseconds / 1000).toStringAsFixed(2)} ms';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = _results[_selectedScenario];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Loop Lab'),
        actions: [
          IconButton(
            key: const Key('lab_clear_btn'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear results',
            onPressed: _isRunning ? null : _clearResults,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ chọn kịch bản
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blueGrey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a scenario:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LabScenario>(
                      key: const Key('lab_scenario_dropdown'),
                      initialValue: _selectedScenario,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: LabScenario.values.map((scenario) {
                        return DropdownMenuItem(
                          value: scenario,
                          child: Text(
                            scenario.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: _isRunning
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedScenario = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    // Giải thích nguyên lý của kịch bản
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedScenario.explanation,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hàng nút điều khiển chạy
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('lab_run_scenario_btn'),
                            icon: _isRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: const Text('Run this scenario'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isRunning ? null : _runCurrent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('lab_run_all_btn'),
                            icon: const Icon(Icons.playlist_play),
                            label: const Text('Run all (6)'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isRunning ? null : _runAll,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Chú thích các hàng đợi trong Dart Event Loop
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event loop processing order:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildQueueLegend(
                        label: '1. SYNC',
                        desc: 'Runs on the call stack',
                        color: Colors.teal.shade700,
                        icon: Icons.flash_on,
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                      _buildQueueLegend(
                        label: '2. MICROTASK',
                        desc: 'scheduleMicrotask, .then',
                        color: Colors.orange.shade800,
                        icon: Icons.bolt,
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                      _buildQueueLegend(
                        label: '3. EVENT',
                        desc: 'Timer, Future(), delayed',
                        color: Colors.purple.shade700,
                        icon: Icons.schedule,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Kết quả thực thi
            if (_isRunning) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Running in a Zone and measuring queues...'),
                    ],
                  ),
                ),
              ),
            ] else if (events == null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No results for this scenario yet.\nTap "Run this scenario" to start.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade300, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Measured execution order (${events.length} steps)',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'Measured via Zone',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Danh sách từng bước thực thi theo thứ tự
                      ListView.separated(
                        key: const Key('lab_events_list'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final (color, icon, queueName) = _getQueueDetails(
                            event.queue,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: color,
                              child: Text(
                                '#${event.sequence}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: color, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 12, color: color),
                                      const SizedBox(width: 4),
                                      Text(
                                        queueName,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  event.label,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              _formatDuration(event.at),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueLegend({
    required String label,
    required String desc,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: TextStyle(fontSize: 9, color: color.withAlpha(200)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
