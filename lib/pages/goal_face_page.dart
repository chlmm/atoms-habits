import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/todo_service.dart';
import '../services/frequency_service.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/habit.dart';
import '../models/todo.dart';

class GoalFacePage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final TodoService? todoService;
  final FrequencyService frequencyService;
  final int? activeGoalId;
  final VoidCallback? onRequestCreateGoal;

  const GoalFacePage({
    super.key,
    required this.goalService,
    required this.habitService,
    this.todoService,
    required this.frequencyService,
    this.activeGoalId,
    this.onRequestCreateGoal,
  });

  @override
  State<GoalFacePage> createState() => _GoalFacePageState();
}

class _GoalFacePageState extends State<GoalFacePage> {
  Goal? _goal;
  List<Milestone> _milestones = [];
  Map<int, double> _milestoneProgress = {};
  Map<int, List<Habit>> _milestoneHabits = {};
  Map<int, List<Todo>> _milestoneTodos = {};
  String? _diagnosis;
  bool _loading = true;

  @override
  void didUpdateWidget(GoalFacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeGoalId != widget.activeGoalId) {
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
          _goal = null;
          _milestones = [];
          _loading = false;
        });
        return;
      }

      final goal = await widget.goalService.getGoal(gid);
      if (goal == null) {
        setState(() {
          _goal = null;
          _loading = false;
        });
        return;
      }

      final ms = await widget.goalService.getMilestonesByGoal(gid);
      final progressMap = <int, double>{};

      for (final m in ms) {
        if (m.id != null) {
          final habits = await widget.habitService.getHabitsByMilestone(m.id!);
          if (habits.isNotEmpty) {
            int total = 0;
            for (final h in habits) {
              total += await widget.habitService.getTotalCompletedCount(h.id!);
            }
            final maxHabits = habits.length *
                FrequencyService.weeklyTarget(habits.first.frequency);
            progressMap[m.id!] =
                maxHabits > 0 ? (total / maxHabits).clamp(0.0, 1.0) : 0.0;
          } else {
            progressMap[m.id!] = m.status == 'completed' ? 1.0 : 0.0;
          }
        }
      }

      _milestoneProgress = progressMap;
      _milestones = ms;

      // 加载每个里程碑的 habits 和 todos
      final mHab = <int, List<Habit>>{};
      final mTd = <int, List<Todo>>{};
      for (final m in ms) {
        if (m.id != null) {
          mHab[m.id!] = await widget.habitService.getHabitsByMilestone(m.id!);
          if (widget.todoService != null) {
            mTd[m.id!] = await widget.todoService!.getTodosForMilestone(m.id!);
          } else {
            mTd[m.id!] = [];
          }
        }
      }
      _milestoneHabits = mHab;
      _milestoneTodos = mTd;

      _goal = goal;
      _diagnosis = _buildDiagnosis(goal, ms, progressMap);
    } catch (_) {
      // graceful
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _buildDiagnosis(
      Goal goal, List<Milestone> ms, Map<int, double> progress) {
    final now = DateTime.now();
    final created = goal.created;
    final totalMs = ms.length;
    final completedMs = ms.where((m) => m.status == 'completed').length;
    final activeMs = ms.where((m) => m.status == 'active').toList();

    final lines = <String>[];

    // Days since start
    final daysSince = now.difference(created).inDays;
    lines.add('开始于 ${daysSince} 天前');

    // Progress
    final totalProgress =
        totalMs > 0 ? (completedMs / totalMs * 100).round() : 0;
    lines.add('总进度 $totalProgress%（里程碑 $completedMs/$totalMs）');

    // Per-habit diagnosis
    final failing = <String>[];
    final passing = <String>[];

    for (final ap in activeMs) {
      final pct = (progress[ap.id] ?? 0) * 100;
      if (pct < 50) {
        failing.add('${ap.name} 完成率 ${pct.round()}%');
      } else if (pct >= 80) {
        passing.add('${ap.name} 完成率 ${pct.round()}%，良好');
      }
    }

    if (failing.isNotEmpty) {
      lines.add('⚠ ${failing.join('；')}');
    }
    if (passing.isNotEmpty) {
      lines.add('✓ ${passing.join('；')}');
    }
    if (failing.isEmpty && passing.isEmpty) {
      lines.add('进度正常，继续保持。');
    }

    return lines.join('\n');
  }

  Future<void> _updateMilestoneProgress(Milestone m) async {
    final controller = TextEditingController(
      text: m.currentValue?.toString() ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.targetDesc != null) Text(m.targetDesc!),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '当前进度',
                hintText: m.targetValue != null
                    ? '目标值：${m.targetValue}'
                    : '输入当前进展',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final value = double.tryParse(controller.text);
    if (value == null) return;

    try {
      await widget.goalService.updateMilestone(
        m.copyWith(currentValue: value),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败：$e')));
    }
  }

  Future<void> _completeMilestone(Milestone m) async {
    // Celebration dialog
    if (!mounted) return;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Text('🎉 '),
          Text('里程碑达成！',
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${m.name}" 已完成！',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Show next milestone info
            FutureBuilder<Milestone?>(
              future: _getNextMilestone(m),
              builder: (_, snapshot) {
                if (snapshot.data != null) {
                  return Text(
                    '下一个里程碑：${snapshot.data!.name}',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface.withAlpha(153),
                    ),
                  );
                }
                return Text(
                  '所有里程碑已完成！',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('稍后处理'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'confirm'),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
    if (confirmed != 'confirm' || !mounted) return;

    try {
      await widget.goalService.completeMilestone(m.id!);
      await _loadData();

      if (!mounted) return;
      // Offer to archive old habits
      await _offerArchiveOldHabits(m);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('失败：$e')));
    }
  }

  Future<Milestone?> _getNextMilestone(Milestone current) async {
    final all = _milestones;
    final idx = all.indexWhere((x) => x.id == current.id);
    if (idx >= 0 && idx < all.length - 1) {
      return all[idx + 1];
    }
    return null;
  }

  Future<void> _offerArchiveOldHabits(Milestone completedMilestone) async {
    final habits = await widget.habitService
        .getHabitsByMilestone(completedMilestone.id!);
    if (habits.isEmpty) return;

    final archive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('归档旧习惯？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('里程碑"${completedMilestone.name}"下的习惯：'),
            const SizedBox(height: 8),
            for (final h in habits.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(h.name),
                ]),
              ),
            if (habits.length > 3)
              Text('...还有 ${habits.length - 3} 个'),
            const SizedBox(height: 16),
            const Text('归档后不再显示，但数据保留。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );

    if (archive == true && mounted) {
      for (final h in habits) {
        await widget.habitService.archiveHabit(h.id!);
      }
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_goal == null) {
      return _buildEmptyState(colorScheme);
    }

    final totalMs = _milestones.length;
    final completedMs =
        _milestones.where((m) => m.status == 'completed').length;
    final progressPercent =
        totalMs > 0 ? (completedMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Goal header ──
          _buildGoalHeader(colorScheme, progressPercent),
          const SizedBox(height: 20),

          // ── Milestone timeline ──
          Text('里程碑时间线',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  )),
          const SizedBox(height: 8),
          ..._milestones.map((m) => _buildMilestoneCard(colorScheme, m)),
          const SizedBox(height: 16),

          // ── Add milestone button ──
          OutlinedButton.icon(
            onPressed: () => _addMilestone(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加里程碑'),
          ),
          const SizedBox(height: 24),

          // ── System diagnosis ──
          _buildDiagnosisCard(colorScheme),
          const SizedBox(height: 32),

          // ── Update progress ──
          if (_milestones.any((m) => m.status == 'active'))
            FilledButton.icon(
              onPressed: () {
                final active = _milestones.firstWhere(
                    (m) => m.status == 'active',
                    orElse: () => _milestones.first);
                _updateMilestoneProgress(active);
              },
              icon: const Icon(Icons.trending_up, size: 18),
              label: const Text('更新里程碑进度'),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '还没有目标。\n设定目标后，这里会显示进度和里程碑。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: widget.onRequestCreateGoal,
              icon: const Icon(Icons.add),
              label: const Text('创建目标'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalHeader(ColorScheme colorScheme, double progress) {
    final pct = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _goal!.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
              if (_goal!.status == 'completed')
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: const Text('已达成',
                      style: TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green.shade100,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text('总体进度 $pct%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(ColorScheme colorScheme, Milestone m) {
    final isActive = m.status == 'active';
    final isCompleted = m.status == 'completed';
    final progress = _milestoneProgress[m.id] ?? 0.0;
    final isLast = _milestones.last.id == m.id;

    IconData icon;
    Color iconColor;
    if (isCompleted) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isActive) {
      icon = Icons.radio_button_checked;
      iconColor = colorScheme.primary;
    } else {
      icon = Icons.radio_button_unchecked;
      iconColor = colorScheme.outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMilestoneDetail(m),
        onLongPress: () => _showMilestoneMenu(m),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline column: dot + vertical line
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: isCompleted
                              ? Colors.green.shade300
                              : colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            style: TextStyle(
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.normal,
                              color: isCompleted
                                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        _statusChip(m),
                      ],
                    ),
                    if (isActive && m.targetValue != null) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (m.currentValue ?? 0) /
                              (m.targetValue! > 0 ? m.targetValue! : 1),
                          minHeight: 4,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.currentValue ?? 0} / ${m.targetValue}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                      ),
                    ],
                    if (isActive && m.targetValue == null && progress > 0) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '习惯完成率 ${(progress * 100).round()}%',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(Milestone m) {
    String label;
    Color labelColor;
    Color bgColor;
    switch (m.status) {
      case 'active':
        label = '进行中';
        labelColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        break;
      case 'completed':
        label = '已完成';
        labelColor = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        break;
      default:
        label = '等待';
        labelColor = Colors.grey.shade600;
        bgColor = Colors.grey.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: labelColor)),
    );
  }

  /// 里程碑详情页（BottomSheet）
  Future<void> _showMilestoneDetail(Milestone m) async {
    final hab = _milestoneHabits[m.id] ?? [];
    final tds = _milestoneTodos[m.id] ?? [];
    final prog = _milestoneProgress[m.id] ?? 0.0;
    final ia = m.status == 'active';
    final ic = m.status == 'completed';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        List<Habit> sHab = List.from(hab);
        List<Todo> sTds = List.from(tds);
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖动条
                  Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  // 标题栏
                  Row(children: [
                    Expanded(child: Text(m.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                    _statusChip(m), const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: '编辑',
                        onPressed: () { Navigator.pop(ctx); _editMilestone(m); }),
                    if (ia) IconButton(icon: Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                        tooltip: '标记完成', onPressed: () { Navigator.pop(ctx); _completeMilestone(m); }),
                  ]),

                  // 进度
                  if (m.targetValue != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (m.currentValue ?? 0) / (m.targetValue! > 0 ? m.targetValue! : 1),
                        minHeight: 8, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${m.currentValue ?? 0} / ${m.targetValue}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      Text('完成 ${(prog * 100).round()}%',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                    ]),
                  ] else if (!ic) ...[
                    const SizedBox(height: 8),
                    Text('习惯完成率 ${(prog * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],

                  // 目标描述
                  if (m.targetDesc != null && m.targetDesc!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(m.targetDesc!, style: TextStyle(fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)))),
                  ],

                  const Divider(height: 24),

                  // 操作按钮
                  Text('操作', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (ia && m.targetValue != null)
                      ActionChip(avatar: const Icon(Icons.trending_up, size: 16),
                          label: const Text('更新进度', style: TextStyle(fontSize: 12)),
                          onPressed: () { Navigator.pop(ctx); _updateMilestoneProgress(m); }),
                    if (widget.todoService != null)
                      ActionChip(avatar: const Icon(Icons.add_task, size: 16, color: Colors.blue),
                          label: const Text('创建待办', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () { Navigator.pop(ctx); _createTodoForMilestone(m); }),
                    ActionChip(avatar: const Icon(Icons.fitness_center, size: 16, color: Colors.purple),
                        label: const Text('关联习惯', style: TextStyle(fontSize: 12, color: Colors.purple)),
                        backgroundColor: Colors.purple.shade50,
                        onPressed: () { Navigator.pop(ctx); _addHabitToMilestone(m); }),
                  ]),

                  const Divider(height: 24),

                  // 关联习惯（可删除）
                  Row(children: [
                    Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('关联习惯 (${sHab.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
                  ]),
                  const SizedBox(height: 6),
                  ..._buildDetailHabits(ctx, sHab, setSheetState, m),

                  const SizedBox(height: 12),

                  // 待办事项（可切换/删除）
                  Row(children: [
                    Icon(Icons.checklist, size: 16, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Text('待办事项 (${sTds.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.tertiary)),
                  ]),
                  const SizedBox(height: 6),
                  ..._buildDetailTodos(ctx, sTds, setSheetState),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
    _loadData();
  }

  /// 构建详情页中的习惯列表项
  List<Widget> _buildDetailHabits(BuildContext ctx, List<Habit> habits, Function ss, Milestone m) {
    if (habits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '暂无关联习惯，点击上方「关联习惯」添加',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        )
      ];
    }
    final items = <Widget>[];
    for (final h in habits) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 14,
                    color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, style: const TextStyle(fontSize: 13)),
                      if (h.time != null)
                        Text(
                          '时间：${h.time}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _frequencyLabel(h.frequency),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                  tooltip: '解除关联',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('解除关联'),
                        content: Text('确认删除习惯「${h.name}」及其所有数据？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('删除')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await widget.habitService.deleteHabit(h.id!);
                      ss(() { habits.removeWhere((x) => x.id == h.id); });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    return items;
  }

  /// 构建详情页中的待办列表项
  List<Widget> _buildDetailTodos(BuildContext ctx, List<Todo> todos, Function ss) {
    if (todos.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '暂无待办，点击上方「创建待办」添加',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        )
      ];
    }
    final items = <Widget>[];
    for (final t in todos) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: t.isCompleted,
                  onChanged: t.isAutoGenerated
                      ? null
                      : (v) async {
                          await widget.todoService!.toggleTodo(t.id!, v ?? false);
                          ss(() {
                            final i = todos.indexWhere((x) => x.id == t.id);
                            if (i >= 0) {
                              todos[i] = todos[i].copyWith(isCompleted: v);
                            }
                          });
                        },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 13,
                      decoration:
                          t.isCompleted ? TextDecoration.lineThrough : null,
                      color: t.isCompleted
                          ? Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)
                          : null,
                    ),
                  ),
                ),
                if (t.date != _todayStr()) ...[
                  Text(
                    t.date,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (t.time != null)
                  Text(
                    t.time!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                if (!t.isAutoGenerated)
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16,
                        color: Colors.red.shade400),
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () async {
                      await widget.todoService!.deleteTodo(t.id!);
                      ss(() { todos.removeWhere((x) => x.id == t.id); });
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return items;
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  String _frequencyLabel(String f) => FrequencyService.frequencyLabel(f);

  Future<void> _createTodoForMilestone(Milestone m) async {
    if (widget.todoService == null) return;
    final tc = TextEditingController();
    final dc = TextEditingController(text: _todayStr());
    final timc = TextEditingController();
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('为「${m.name}」创建待办'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tc, autofocus: true,
                  decoration: const InputDecoration(labelText: '待办内容', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: dc, keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: '日期 (YYYY-MM-DD)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: timc,
                  decoration: const InputDecoration(labelText: '时间 (可选, HH:mm)',
                    hintText: '如：09:00', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (tc.text.trim().isNotEmpty && dc.text.trim().isNotEmpty) Navigator.pop(ctx, {
              'title': tc.text.trim(),
              'date': dc.text.trim(),
              'time': timc.text.trim().isEmpty ? null : timc.text.trim(),
            });
          }, child: const Text('创建')),
        ],
      ),
    );
    if (r == null) return;
    await widget.todoService!.createManualTodo(
      title: r['title'] as String,
      milestoneId: m.id,
      date: r['date'] as String?,
      time: r['time'] as String?,
    );
    await _loadData();
  }

  Future<void> _addHabitToMilestone(Milestone m) async {
    String selectedFrequency = 'daily';
    Set<int> selectedWeekdays = {};
    final nc = TextEditingController();
    final tc = TextEditingController();
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, dSet) => AlertDialog(
            title: Text('为「${m.name}」关联习惯'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nc, autofocus: true,
                      decoration: const InputDecoration(labelText: '习惯名称', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: tc, readOnly: true,
                      decoration: InputDecoration(
                        labelText: '提醒时间（可选）',
                        hintText: '点击选择时间',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                          if (t != null) { tc.text = t.format(context); }
                        }),
                      )),
                  const SizedBox(height: 16),
                  Text('频率', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    ChoiceChip(label: const Text('每天'), selected: selectedFrequency == 'daily',
                        onSelected: (_) { dSet(() => selectedFrequency = 'daily'); }),
                    ChoiceChip(label: const Text('每两天'), selected: selectedFrequency == 'every_other',
                        onSelected: (_) { dSet(() => selectedFrequency = 'every_other'); }),
                    ChoiceChip(label: const Text('每周'), selected: selectedFrequency == 'weekly',
                        onSelected: (_) { dSet(() => selectedFrequency = 'weekly'); }),
                    ChoiceChip(label: const Text('每周两次'), selected: selectedFrequency == 'twice_week',
                        onSelected: (_) { dSet(() => selectedFrequency = 'twice_week'); }),
                    ChoiceChip(label: const Text('自定义'), selected: selectedFrequency == 'custom',
                        onSelected: (_) { dSet(() => selectedFrequency = 'custom'); }),
                  ]),
                  if (selectedFrequency == 'custom') ...[
                    const SizedBox(height: 10),
                    Text('选择星期', style: TextStyle(fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      for (final entry in <String, int>{'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'日':7}.entries)
                        FilterChip(label: Text(entry.key), selected: selectedWeekdays.contains(entry.value),
                            onSelected: (v) { dSet(() { if (v) selectedWeekdays.add(entry.value); else selectedWeekdays.remove(entry.value); }); }),
                    ]),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(onPressed: () {
                if (nc.text.trim().isNotEmpty) Navigator.pop(ctx, {
                  'name': nc.text.trim(),
                  'frequency': selectedFrequency,
                  'customDays': selectedFrequency == 'custom' && selectedWeekdays.isNotEmpty
                      ? selectedWeekdays.toList() : null,
                  'time': tc.text.trim().isEmpty ? null : tc.text.trim(),
                });
              }, child: const Text('创建')),
            ],
          ),
        );
      },
    );
    if (r == null) return;
    await widget.habitService.createHabit(m.id!, r['name'] as String, r['frequency'] as String,
      customDays: r['customDays'] != null
          ? (r['customDays'] as List).map((e) => e.toString()).join(',') : null,
      time: r['time'] as String?);
    await _loadData();
  }

  void _showMilestoneMenu(Milestone m) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _editMilestone(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('上移'),
              enabled: m.sortOrder > 0,
              onTap: () {
                Navigator.pop(ctx);
                _reorderMilestone(m, -1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('下移'),
              enabled: m.sortOrder < _milestones.length - 1,
              onTap: () {
                Navigator.pop(ctx);
                _reorderMilestone(m, 1);
              },
            ),
            if (m.status == 'active')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('标记完成',
                    style: TextStyle(color: Colors.green)),
                onTap: () {
                  Navigator.pop(ctx);
                  _completeMilestone(m);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMilestone(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMilestone(Milestone m) async {
    final nc = TextEditingController(text: m.name);
    final dc = TextEditingController(text: m.targetDesc ?? '');
    final vc = TextEditingController(text: m.targetValue != null ? m.targetValue!.toString() : '');
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑里程碑'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nc, autofocus: true,
                  decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: dc, decoration: const InputDecoration(
                labelText: '目标描述（可选）', hintText: '如：每周跑3次，每次30分钟',
                border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: vc, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '目标值（可选）',
                    hintText: '如：100、5公里等，用于追踪进度', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx, {
              'name': nc.text.trim(),
              'targetDesc': dc.text.trim().isEmpty ? null : dc.text.trim(),
              'targetValue': double.tryParse(vc.text),
            });
          }, child: const Text('保存')),
        ],
      ),
    );
    if (r == null) return;
    await widget.goalService.updateMilestone(m.copyWith(
      name: r['name'] as String,
      targetDesc: r['targetDesc'] as String?,
      targetValue: r['targetValue'] as double?,
    ));
    await _loadData();
  }

  Future<void> _reorderMilestone(Milestone m, int delta) async {
    await widget.goalService.updateMilestone(
      m.copyWith(sortOrder: m.sortOrder + delta),
    );
    await _loadData();
  }

  Future<void> _deleteMilestone(Milestone m) async {
    if (m.status == 'completed' || m.status == 'active') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除里程碑'),
          content: const Text('该里程碑已激活/完成，关联的习惯将保留但不再显示。确认删除？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await widget.goalService.deleteMilestone(m.id!);
    await _loadData();
  }

  Future<void> _addMilestone() async {
    final nc = TextEditingController();
    final dc = TextEditingController();
    final vc = TextEditingController();
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加里程碑'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nc, autofocus: true,
                  decoration: const InputDecoration(labelText: '里程碑名称', hintText: '如：完成 1 个引体向上',
                    border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: dc, decoration: const InputDecoration(
                labelText: '目标描述（可选）', hintText: '如：每周跑3次，每次30分钟',
                border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: vc, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '目标值（可选）',
                    hintText: '如：100、5公里等，用于追踪进度', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (nc.text.trim().isNotEmpty) Navigator.pop(ctx, {
              'name': nc.text.trim(),
              'targetDesc': dc.text.trim().isEmpty ? null : dc.text.trim(),
              'targetValue': double.tryParse(vc.text),
            });
          }, child: const Text('添加')),
        ],
      ),
    );
    if (r == null) return;
    await widget.goalService.createMilestone(_goal!.id!, r['name'] as String,
      targetDesc: r['targetDesc'] as String?, targetValue: r['targetValue'] as double?);
    await _loadData();
  }

  Widget _buildDiagnosisCard(ColorScheme colorScheme) {
    if (_diagnosis == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20,
                  color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('系统诊断',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _diagnosis!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
