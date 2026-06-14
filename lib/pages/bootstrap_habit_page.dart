import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../models/habit.dart';
import '../models/action_plan.dart';
import '../models/log_entry.dart';

class BootstrapHabitPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;

  const BootstrapHabitPage({
    super.key,
    required this.goalService,
    required this.habitService,
  });

  @override
  State<BootstrapHabitPage> createState() => _BootstrapHabitPageState();
}

class _BootstrapHabitPageState extends State<BootstrapHabitPage> {
  String? _goalName;
  String? _milestoneName;
  List<Habit> _habits = [];
  Map<int, List<ActionPlan>> _habitActions = {};
  Map<int, LogEntry?> _todayLogs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final goals = await widget.goalService.getActiveGoals();
      if (goals.isEmpty) {
        setState(() {
          _goalName = null;
          _loading = false;
        });
        return;
      }

      final activeGoal = goals.first;
      _goalName = activeGoal.name;

      final activeMs =
          await widget.goalService.getActiveMilestone(activeGoal.id!);
      if (activeMs == null) {
        setState(() {
          _milestoneName = null;
          _loading = false;
        });
        return;
      }

      _milestoneName = activeMs.name;

      final habits = await widget.habitService
          .getHabitsByMilestone(activeMs.id!);
      _habits = habits;

      final actionMap = <int, List<ActionPlan>>{};
      for (final h in habits) {
        actionMap[h.id!] =
            await widget.habitService.getActionPlansForHabit(h.id!);
      }
      _habitActions = actionMap;

      final logMap = <int, LogEntry?>{};
      for (final h in habits) {
        logMap[h.id!] = await widget.habitService.getLogToday(h.id!);
      }
      _todayLogs = logMap;
    } catch (_) {
      // Graceful: show empty state
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _completeFull(int habitId) async {
    final actions = _habitActions[habitId] ?? [];
    final completions = <String, bool>{};
    for (final a in actions) {
      if (a.id != null) completions[a.id!.toString()] = true;
    }
    try {
      await widget.habitService.completeHabit(
        habitId,
        status: 'full',
        actionCompletions: completions,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败：$e')));
    }
  }

  Future<void> _completeTwoMin(int habitId) async {
    final habit = _habits.firstWhere((h) => h.id == habitId);
    final safetyValve = habit.twoMinVer ?? '只做两分钟';

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('只做两分钟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全阀：$safetyValve'),
            const SizedBox(height: 8),
            const Text('确认执行两分钟版本？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.habitService.completeHabit(habitId, status: 'two_min');
      await _loadData();

      if (!mounted) return;
      final upgrade = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('两分钟完成！'),
          content: const Text('要继续完整版吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('今天就到这里'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续完整版'),
            ),
          ],
        ),
      );
      if (upgrade == true && mounted) {
        await widget.habitService.completeHabit(habitId, status: 'full');
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败：$e')));
    }
  }

  Future<void> _skipHabit(int habitId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳过今天？'),
        content: const Text('确定要跳过这个习惯吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('跳过'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.habitService.skipHabit(habitId);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atoms'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goalName == null
              ? _buildEmptyState(colorScheme, '还没有目标。\n去创建一个吧！')
              : _milestoneName == null
                  ? _buildEmptyState(colorScheme, '里程碑已完成。\n去目标面添加新里程碑！')
                  : _buildHabitList(colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.self_improvement, size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Milestone header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_goalName ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text('$_milestoneName',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
          // Habit cards
          ..._habits.map((h) => _buildHabitCard(colorScheme, h)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHabitCard(ColorScheme colorScheme, Habit habit) {
    final log = _todayLogs[habit.id];
    final isCompleted = log != null && log.status == LogStatus.full;
    final isTwoMin = log != null && log.status == LogStatus.twoMin;
    final isSkipped = log != null && log.status == LogStatus.skipped;
    final actions = _habitActions[habit.id] ?? [];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.shade300
              : isSkipped
                  ? Colors.grey.shade300
                  : colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusIcon(isCompleted, isTwoMin, isSkipped),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: isSkipped ? TextDecoration.lineThrough : null,
                      color: isSkipped ? Colors.grey : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_frequencyLabel(habit.frequency),
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Action items
            ...actions.map((a) => Padding(
                  padding: const EdgeInsets.only(left: 52, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: isCompleted
                            ? Colors.green
                            : isSkipped
                                ? Colors.grey
                                : colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        a.name,
                        style: TextStyle(
                          color: isSkipped
                              ? Colors.grey
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCompleted && !isTwoMin && !isSkipped) ...[
                  TextButton.icon(
                    onPressed: () => _completeTwoMin(habit.id!),
                    icon: const Icon(Icons.timer_outlined, size: 16),
                    label: const Text('只做两分钟'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _completeFull(habit.id!),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('全部完成'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _skipHabit(habit.id!),
                    child: const Text('跳过',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ] else if (isTwoMin) ...[
                  Chip(
                    avatar: const Icon(Icons.check, size: 16, color: Colors.orange),
                    label: const Text('两分钟',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _completeFull(habit.id!),
                    child: const Text('升级为完整版'),
                  ),
                ] else if (isCompleted) ...[
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    label: const Text('已完成',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ] else if (isSkipped) ...[
                  Chip(
                    avatar: const Icon(Icons.skip_next, size: 16, color: Colors.grey),
                    label: const Text('已跳过',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    backgroundColor: const Color(0xFFF5F5F5),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isCompleted, bool isTwoMin, bool isSkipped) {
    if (isCompleted) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
      );
    }
    if (isTwoMin) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.check_circle_outline,
            color: Colors.orange.shade600, size: 28),
      );
    }
    if (isSkipped) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.cancel_outlined, color: Colors.grey, size: 28),
      );
    }
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 28),
    );
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily': return '每天';
      case 'every_other': return '每两天';
      case 'weekly': return '每周';
      case 'twice_week': return '每周两次';
      default: return f;
    }
  }
}
