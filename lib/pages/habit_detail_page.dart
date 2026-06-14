import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/frequency_service.dart';
import '../models/habit.dart';
import '../models/action_plan.dart';
import '../models/log_entry.dart';
import '../models/milestone.dart';

class HabitDetailPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final FrequencyService frequencyService;
  final int habitId;

  const HabitDetailPage({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.frequencyService,
    required this.habitId,
  });

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  Habit? _habit;
  Milestone? _milestone;
  List<ActionPlan> _actions = [];
  LogEntry? _todayLog;
  int _totalCompleted = 0;
  Map<String, String> _recentStatuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final habit = await widget.habitService.getHabit(widget.habitId);
      if (habit == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        widget.goalService.getMilestone(habit.milestoneId),
        widget.habitService.getActionPlansForHabit(habit.id!),
        widget.habitService.getLogToday(habit.id!),
        widget.habitService.getTotalCompletedCount(habit.id!),
        widget.habitService.getRecentStatuses(habit.id!, 7),
      ]);

      if (!mounted) return;
      setState(() {
        _habit = habit;
        _milestone = results[0] as Milestone?;
        _actions = results[1] as List<ActionPlan>;
        _todayLog = results[2] as LogEntry?;
        _totalCompleted = results[3] as int;
        _recentStatuses = Map<String, String>.from(results[4] as Map<String, String>);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily': return '每天';
      case 'every_other': return '每两天';
      case 'twice_week': return '每周两次';
      case 'weekly': return '每周';
      default: return f;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('习惯详情')),
        body: const Center(child: Text('习惯未找到')),
      );
    }

    final habit = _habit!;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context, '/edit-habit',
                arguments: habit.id,
              );
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(habit, colorScheme),
          const SizedBox(height: 16),
          _buildActionItems(colorScheme),
          const SizedBox(height: 16),
          _buildProgressSection(colorScheme),
          const SizedBox(height: 16),
          _buildWeekStrip(colorScheme),
          const SizedBox(height: 16),
          _buildNeverMissTwice(colorScheme),
          const SizedBox(height: 16),
          _buildQuickActions(colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Habit habit, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.repeat, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('频率：${_frequencyLabel(habit.frequency)}'),
            ]),
            if (_milestone != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.flag_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('里程碑：${_milestone!.name}')),
              ]),
            ],
            if (habit.twoMinVer != null && habit.twoMinVer!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.shield_outlined, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text('安全阀：${habit.twoMinVer}')),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItems(ColorScheme colorScheme) {
    if (_actions.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('行动项',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            ..._actions.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(a.name),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 28),
          const SizedBox(width: 12),
          Text('累计完成 $_totalCompleted 次',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildWeekStrip(ColorScheme colorScheme) {
    final now = DateTime.now();
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近七天',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final date = now.subtract(Duration(days: 6 - i));
                final dateStr =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final status = _recentStatuses[dateStr];
                final isFull = status == 'full';
                final isTwoMin = status == 'two_min';
                final isSkipped = status == 'skipped';
                final isToday = i == 6;

                Color dotColor;
                Widget? icon;
                if (isFull) {
                  dotColor = Colors.green;
                  icon = const Icon(Icons.check, color: Colors.white, size: 16);
                } else if (isTwoMin) {
                  dotColor = Colors.orange;
                  icon = const Icon(Icons.check, color: Colors.white, size: 16);
                } else if (isSkipped) {
                  dotColor = Colors.grey;
                  icon = const Icon(Icons.close, color: Colors.white, size: 14);
                } else {
                  dotColor = Colors.grey.shade300;
                  icon = null;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        border: isToday
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Center(child: icon),
                    ),
                    const SizedBox(height: 4),
                    Text(date.day.toString(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : null)),
                    Text(dayNames[date.weekday - 1],
                        style: TextStyle(
                            fontSize: 10, color: colorScheme.outline)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeverMissTwice(ColorScheme colorScheme) {
    // Check: yesterday was a training day AND was skipped, AND today is a training day AND not yet done
    final habit = _habit;
    if (habit == null) return const SizedBox.shrink();

    // Simplified: just check if today not done + yesterday was skipped
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final yesterdayStatus = _recentStatuses[yesterdayStr];
    final todayDone = _todayLog != null && _todayLog!.status != LogStatus.skipped;
    final yesterdaySkipped = yesterdayStatus == 'skipped';

    if (yesterdaySkipped && !todayDone) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '昨天已经错过了一次，今天不能再错过了！',
                style: TextStyle(
                    color: Colors.orange.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
    }

    if (yesterdaySkipped && todayDone) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.check_circle_outline,
                color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '做得好！打破了连续错过的模式。',
                style: TextStyle(
                    color: Colors.green.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.trending_up, color: Colors.green.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '继续保持！',
              style: TextStyle(
                  color: Colors.green.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    return Column(children: [
      OutlinedButton.icon(
        onPressed: () async {
          await widget.habitService.archiveHabit(widget.habitId);
          if (mounted) Navigator.pop(context, true);
        },
        icon: const Icon(Icons.archive),
        label: const Text('归档习惯'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    ]);
  }
}
