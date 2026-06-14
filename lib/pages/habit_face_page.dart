import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/frequency_service.dart';
import '../services/identity_service.dart';
import '../models/habit.dart';
import '../models/action_plan.dart';
import '../models/log_entry.dart';
import '../models/milestone.dart';
import '../models/identity_insight.dart';
import '../widgets/identity_insight_dialog.dart';

class HabitFacePage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final FrequencyService frequencyService;
  final int? activeGoalId;
  final VoidCallback? onRequestCreateHabit;

  const HabitFacePage({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.frequencyService,
    this.activeGoalId,
    this.onRequestCreateHabit,
  });

  @override
  State<HabitFacePage> createState() => _HabitFacePageState();
}

class _HabitFacePageState extends State<HabitFacePage> {
  Milestone? _activeMilestone;
  List<Habit> _habits = [];
  Map<int, List<ActionPlan>> _habitActions = {};
  Map<int, LogEntry?> _todayLogs = {};
  Map<int, bool> _trainingDays = {};
  Map<int, Set<int>> _checkedActions = {}; // habitId → set of checked actionPlanIds
  bool _loading = true;

  @override
  void didUpdateWidget(HabitFacePage old) {
    super.didUpdateWidget(old);
    if (old.activeGoalId != widget.activeGoalId) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final gid = widget.activeGoalId;
      if (gid == null) {
        setState(() {
          _activeMilestone = null;
          _habits = [];
          _loading = false;
        });
        return;
      }

      final activeMs = await widget.goalService.getActiveMilestone(gid);
      _activeMilestone = activeMs;

      List<Habit> habits;
      if (activeMs != null) {
        habits = await widget.habitService
            .getHabitsByMilestone(activeMs.id!);
      } else {
        habits = [];
      }
      _habits = habits;

      // Load actions & logs & training-day status in parallel batches
      final actionMap = <int, List<ActionPlan>>{};
      final logMap = <int, LogEntry?>{};
      final tdMap = <int, bool>{};

      for (final h in habits) {
        final hid = h.id!;
        final actions =
            await widget.habitService.getActionPlansForHabit(hid);
        final log = await widget.habitService.getLogToday(hid);
        final logs = await widget.habitService.getLogsForHabit(hid, limit: 30);

        actionMap[hid] = actions;
        logMap[hid] = log;
        tdMap[hid] =
            widget.frequencyService.isTrainingDaySync(h, logs);
      }

      _habitActions = actionMap;
      _todayLogs = logMap;
      _trainingDays = tdMap;

      // Init checked actions from today's log
      final checkedMap = <int, Set<int>>{};
      for (final h in habits) {
        final hid = h.id!;
        final log = logMap[hid];
        if (log != null && log.actionCompletions != null) {
          try {
            final decoded = jsonDecode(log.actionCompletions!) as Map<String, dynamic>;
            final checked = <int>{};
            decoded.forEach((key, value) {
              if (value == true) checked.add(int.parse(key));
            });
            checkedMap[hid] = checked;
          } catch (_) {
            checkedMap[hid] = {};
          }
        } else {
          checkedMap[hid] = {};
        }
      }
      _checkedActions = checkedMap;
    } catch (_) {
      // graceful
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // ── Habit actions ────────────────────────────────────

  void _toggleAction(int habitId, int actionId, bool currentlyChecked) {
    setState(() {
      if (currentlyChecked) {
        _checkedActions[habitId]?.remove(actionId);
      } else {
        _checkedActions[habitId]?.add(actionId);
      }
    });
  }

  Future<void> _completeFull(int habitId) async {
    final checked = _checkedActions[habitId] ?? {};
    final actions = _habitActions[habitId] ?? [];
    final completions = <String, bool>{};
    for (final a in actions) {
      if (a.id != null) {
        completions[a.id!.toString()] = checked.contains(a.id);
      }
    }
    // If no individual actions were checked, mark all as done
    if (checked.isEmpty && actions.isNotEmpty) {
      for (final a in actions) {
        if (a.id != null) completions[a.id!.toString()] = true;
      }
    }
    try {
      await widget.habitService.completeHabit(
        habitId,
        status: 'full',
        actionCompletions: completions,
      );
      await _loadData();
      if (mounted) _checkIdentityInsight(habitId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('失败：$e')));
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
      if (mounted) _checkIdentityInsight(habitId);

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('失败：$e')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('失败：$e')));
    }
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.activeGoalId == null) {
      return _buildEmptyState(colorScheme,
          '还没有目标。\n去目标面或从引导创建一个目标吧！');
    }

    if (_activeMilestone == null) {
      return _buildEmptyState(colorScheme,
          '当前没有进行中的里程碑。\n去目标面激活或添加一个里程碑！');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Milestone header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前里程碑',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(
                  _activeMilestone!.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),

          // ── Habit cards ──
          if (_habits.isEmpty)
            _buildEmptyHabitsHint(colorScheme)
          else
            ..._habits.map((h) => _buildHabitCard(colorScheme, h)),

          const SizedBox(height: 80),
        ],
      ),
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        colorScheme.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHabitsHint(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.add_task_outlined, size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '还没有习惯。\n为当前里程碑创建第一个习惯吧。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(ColorScheme colorScheme, Habit habit) {
    final log = _todayLogs[habit.id];
    final isCompleted = log != null && log.status == LogStatus.full;
    final isTwoMin = log != null && log.status == LogStatus.twoMin;
    final isSkipped = log != null && log.status == LogStatus.skipped;
    final actions = _habitActions[habit.id] ?? [];
    final isTraining = _trainingDays[habit.id] ?? true;

    // Non-training day → grey out, disable actions EXCEPT skip
    final greyedOut = !isTraining && !isCompleted && !isTwoMin && !isSkipped;

    return Opacity(
      opacity: greyedOut ? 0.5 : 1.0,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCompleted
                ? Colors.green.shade300
                : isSkipped
                    ? Colors.grey.shade300
                    : greyedOut
                        ? colorScheme.outline.withValues(alpha: 0.1)
                        : colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Row(
                children: [
                  _buildStatusIcon(isCompleted, isTwoMin, isSkipped,
                      greyedOut),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration:
                            isSkipped ? TextDecoration.lineThrough : null,
                        color: isSkipped
                            ? Colors.grey
                            : greyedOut
                                ? colorScheme.onSurface
                                    .withValues(alpha: 0.4)
                                : null,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: greyedOut
                          ? Colors.grey.shade200
                          : colorScheme.secondaryContainer
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      greyedOut
                          ? '休息日'
                          : _frequencyLabel(habit.frequency),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Action items (checkable) ──
              ...actions.map((a) {
                final checked = _checkedActions[habit.id]?.contains(a.id) ?? false;
                final canCheck = !isCompleted && !isSkipped && !greyedOut;
                return Padding(
                    padding: const EdgeInsets.only(left: 52, bottom: 4),
                    child: InkWell(
                      onTap: canCheck ? () => _toggleAction(habit.id!, a.id!, checked) : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Icon(
                            checked
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: checked
                                ? Colors.green
                                : isSkipped
                                    ? Colors.grey
                                    : greyedOut
                                        ? Colors.grey.shade300
                                        : colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            a.name,
                            style: TextStyle(
                              color: isSkipped
                                  ? Colors.grey
                                  : greyedOut
                                      ? Colors.grey.shade400
                                      : colorScheme.onSurface,
                              decoration: checked && !isCompleted ? null : null,
                            ),
                          ),
                        ],
                      ),
                    ));
                  }),
              const SizedBox(height: 8),

              // ── Safety valve hint ──
              if (habit.twoMinVer != null && !isCompleted && !isSkipped)
                Padding(
                  padding: const EdgeInsets.only(left: 52, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          habit.twoMinVer!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Action buttons ──
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Before any action
                  if (!isCompleted && !isTwoMin && !isSkipped) ...[
                    if (!greyedOut) ...[
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
                    ],
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _skipHabit(habit.id!),
                      child: const Text('跳过',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ]
                  // Two-min done
                  else if (isTwoMin) ...[
                    Chip(
                      avatar: const Icon(Icons.check, size: 16,
                          color: Colors.orange),
                      label: const Text('两分钟',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 12)),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _completeFull(habit.id!),
                      child: const Text('升级为完整版'),
                    ),
                  ]
                  // Full done
                  else if (isCompleted) ...[
                    Chip(
                      avatar: const Icon(Icons.check_circle, size: 16,
                          color: Colors.green),
                      label: const Text('已完成',
                          style: TextStyle(
                              color: Colors.green, fontSize: 12)),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ]
                  // Skipped
                  else if (isSkipped) ...[
                    Chip(
                      avatar: const Icon(Icons.skip_next, size: 16,
                          color: Colors.grey),
                      label: const Text('已跳过',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
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
      ),
    );
  }

  // ── Identity Insight Check ────────────────────────────

  Future<void> _checkIdentityInsight(int habitId) async {
    try {
      final db = widget.habitService.db;
      final identityService = IdentityService(db);
      final triggers = await identityService.checkTriggers();

      // Find trigger for this habit
      final trigger = triggers.where((t) => t['habit_id'] == habitId).toList();
      if (trigger.isEmpty) return;

      final t = trigger.first;
      final habitName = t['habit_name'] as String;
      final totalCompleted = t['total_completed'] as int;

      // Get goal name for better identity text generation
      String goalName = '';
      final goalId = widget.activeGoalId;
      if (goalId != null) {
        final goal = await widget.goalService.getGoal(goalId);
        goalName = goal?.name ?? '';
      }

      final suggestedIdentity =
          identityService.generateIdentityText(habitName, goalName);

      if (!mounted) return;
      final result = await showIdentityInsightDialog(
        context,
        habitName: habitName,
        totalCompleted: totalCompleted,
        suggestedIdentity: suggestedIdentity,
      );

      if (result != null && mounted) {
        final insight = IdentityInsight(
          goalId: goalId,
          text: result == 'accepted' ? suggestedIdentity : result,
          accepted: true,
          triggeredBy: 'habit_id=$habitId',
        );
        await identityService.createInsight(insight);
      }
    } catch (_) {
      // Graceful — identity insight is non-critical
    }
  }

  // ── Helpers ──────────────────────────────────────────

  Widget _buildStatusIcon(
      bool isCompleted, bool isTwoMin, bool isSkipped, bool greyedOut) {
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
        child:
            const Icon(Icons.cancel_outlined, color: Colors.grey, size: 28),
      );
    }
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: greyedOut ? Colors.grey.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.circle_outlined,
          color: greyedOut ? Colors.grey.shade300 : Colors.grey.shade400,
          size: 28),
    );
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily':
        return '每天';
      case 'every_other':
        return '每两天';
      case 'weekly':
        return '每周';
      case 'twice_week':
        return '每周两次';
      default:
        return f;
    }
  }
}
