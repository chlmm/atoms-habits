import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';

class GoalCreatePage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;

  const GoalCreatePage({
    super.key,
    required this.goalService,
    required this.habitService,
  });

  @override
  State<GoalCreatePage> createState() => _GoalCreatePageState();
}

class _GoalCreatePageState extends State<GoalCreatePage> {
  final PageController _pageController = PageController();

  // Step 1
  String _goalName = '';
  final _goalController = TextEditingController();

  // Step 2
  final List<String> _milestones = [];

  // Step 3
  final List<String> _actions = [];

  // Step 4 — list of habit definitions
  final List<_HabitDraft> _habits = [_HabitDraft()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _habits.first.setAvailableActions(_actions);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    for (final h in _habits) {
      h.nameController.dispose();
      h.safetyController.dispose();
    }
    super.dispose();
  }

  void _nextPage() {
    if (_pageController.page?.round() == 0 && _goalName.trim().isEmpty) {
      _showSnackBar('请输入你的目标');
      return;
    }
    if (_pageController.page?.round() == 1 && _milestones.isEmpty) {
      _showSnackBar('至少添加一个里程碑');
      return;
    }
    if (_pageController.page?.round() == 2 && _actions.isEmpty) {
      _showSnackBar('至少添加一个行动');
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── Step 2 helpers ──────────────────────────────────

  Future<void> _addMilestone() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _inputDialog(ctx, '添加里程碑', '这个阶段你要完成什么？'),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _milestones.add(result.trim()));
    }
  }

  void _removeMilestone(int index) {
    setState(() => _milestones.removeAt(index));
  }

  // ── Step 3 helpers ──────────────────────────────────

  Future<void> _addAction() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _inputDialog(ctx, '添加行动', '具体要做什么？'),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _actions.add(result.trim());
        for (final h in _habits) {
          h.setAvailableActions(_actions);
        }
      });
    }
  }

  void _removeAction(int index) {
    setState(() {
      _actions.removeAt(index);
      for (final h in _habits) {
        h.setAvailableActions(_actions);
      }
    });
  }

  // ── Step 4 helpers ──────────────────────────────────

  void _addHabit() {
    final draft = _HabitDraft();
    draft.setAvailableActions(_actions);
    setState(() => _habits.add(draft));
  }

  void _removeHabit(int index) {
    if (_habits.length == 1) return;
    final removed = _habits.removeAt(index);
    removed.nameController.dispose();
    removed.safetyController.dispose();
    setState(() {});
  }

  Future<void> _saveAll() async {
    // Validate habit names
    for (final h in _habits) {
      if (h.nameController.text.trim().isEmpty) {
        _showSnackBar('每个习惯都需要一个名称');
        return;
      }
    }
    // Validate at least one action per habit
    for (final h in _habits) {
      if (h.selectedIndices.isEmpty) {
        _showSnackBar('"${h.nameController.text}"至少需要一个行动');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      // 1. Create goal
      final goal = await widget.goalService.createGoal(_goalName.trim());

      // 2. Create milestones
      for (final m in _milestones) {
        await widget.goalService.createMilestone(goal.id!, m);
      }

      // 3. Create action plans for the first milestone
      final activeMs = await widget.goalService.getActiveMilestone(goal.id!);
      final actionPlanIds = <int>[];
      for (final a in _actions) {
        final ap = await widget.goalService.createActionPlan(activeMs!.id!, a);
        actionPlanIds.add(ap.id!);
      }

      // 4. Create habits
      for (final h in _habits) {
        final selectedActionIds =
            h.selectedIndices.map((i) => actionPlanIds[i]).toList();
        await widget.habitService.createHabit(
          activeMs!.id!,
          h.nameController.text.trim(),
          h.frequency,
          actionPlanIds: selectedActionIds,
          twoMinVer: h.safetyController.text.trim().isEmpty
              ? null
              : h.safetyController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败：$e');
      setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return Scaffold(
        appBar: AppBar(title: const Text('创建目标')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在保存...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建目标'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStepGoal(),
          _buildStepMilestones(),
          _buildStepActionPlans(),
          _buildStepHabits(),
        ],
      ),
    );
  }

  // ── Step 1: Goal ────────────────────────────────────

  Widget _buildStepGoal() {
    final colorScheme = Theme.of(context).colorScheme;
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text('你想达成什么？',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('设定一个具体成果，例如减掉 10 公斤、每天精力充沛。',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 24),
          TextField(
            controller: _goalController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '减掉 10 公斤 / 完成双力臂 / 每天精力充沛 ...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (v) => _goalName = v,
            onSubmitted: (_) => _nextPage(),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('下一步'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step 2: Milestones ──────────────────────────────

  Widget _buildStepMilestones() {
    final colorScheme = Theme.of(context).colorScheme;
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            '要达成"$_goalName"，\n需要过哪些关口？',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('第一关会自动激活，后面的达标后才解锁。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          Expanded(
            child: _milestones.isEmpty
                ? Center(
                    child: Text('点击下方按钮添加你的第一个里程碑',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4))))
                : ListView.builder(
                    itemCount: _milestones.length,
                    itemBuilder: (ctx, i) {
                      final isFirst = i == 0;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            isFirst
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isFirst
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          title: Text('${i + 1}  ${_milestones[i]}'),
                          subtitle: isFirst
                              ? const Text('自动激活',
                                  style: TextStyle(fontSize: 12))
                              : null,
                          trailing: IconButton(
                            icon: Icon(Icons.close,
                                color: colorScheme.error.withValues(alpha: 0.5)),
                            onPressed: () => _removeMilestone(i),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addMilestone,
            icon: const Icon(Icons.add),
            label: const Text('添加里程碑'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: _prevPage, child: const Text('上一步')),
              FilledButton(onPressed: _nextPage, child: const Text('下一步')),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step 3: Action Plans ────────────────────────────

  Widget _buildStepActionPlans() {
    final colorScheme = Theme.of(context).colorScheme;
    final firstM = _milestones.isNotEmpty ? _milestones[0] : '';

    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            '为"$firstM"\n列出需要做的行为。',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('先列出来，后面再打包。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          Expanded(
            child: _actions.isEmpty
                ? Center(
                    child: Text('点击底部按钮添加行动',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4))))
                : ListView.builder(
                    itemCount: _actions.length,
                    itemBuilder: (ctx, i) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        leading: const Icon(Icons.circle_outlined, size: 12),
                        title: Text('${i + 1}  ${_actions[i]}'),
                        trailing: IconButton(
                          icon: Icon(Icons.close,
                              color: colorScheme.error.withValues(alpha: 0.5)),
                          onPressed: () => _removeAction(i),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addAction,
            icon: const Icon(Icons.add),
            label: const Text('添加行动'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: _prevPage, child: const Text('上一步')),
              FilledButton(onPressed: _nextPage, child: const Text('下一步')),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step 4: Habits ──────────────────────────────────

  Widget _buildStepHabits() {
    final colorScheme = Theme.of(context).colorScheme;

    final unassigned = _actions
        .where((a) => !_habits.any((h) => h.isSelected(a)))
        .toList();

    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            '把行动打包成习惯',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('给每组起名、选频率、加安全阀。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _habits.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _habits.length) {
                  return OutlinedButton.icon(
                    onPressed: _addHabit,
                    icon: const Icon(Icons.add),
                    label: const Text('再建一个习惯'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  );
                }
                return _buildHabitCard(colorScheme, i);
              },
            ),
          ),
          if (unassigned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('还有 ${unassigned.length} 个行动未分配',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  )),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: _prevPage, child: const Text('上一步')),
              FilledButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.check),
                label: const Text('保存并开始'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHabitCard(ColorScheme colorScheme, int index) {
    final h = _habits[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: h.nameController,
                    decoration: InputDecoration(
                      hintText: '习惯名称（如练背计划）',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: _habits.length > 1
                      ? () => _removeHabit(index)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: h.frequency,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('每天')),
                DropdownMenuItem(
                    value: 'every_other', child: Text('每两天')),
                DropdownMenuItem(
                    value: 'weekly', child: Text('每周一次')),
                DropdownMenuItem(
                    value: 'twice_week', child: Text('每周两次')),
                DropdownMenuItem(
                    value: 'custom', child: Text('自定义')),
              ],
              onChanged: (v) {
                setState(() => h.frequency = v!);
              },
            ),
            const SizedBox(height: 8),
            if (_actions.isNotEmpty) ...[
              Text('从行动计划中挑选：',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              for (var j = 0; j < _actions.length; j++)
                CheckboxListTile(
                  value: h.selectedIndices.contains(j),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        h.selectedIndices.add(j);
                      } else {
                        h.selectedIndices.remove(j);
                      }
                    });
                  },
                  title: Text(_actions[j],
                      style: Theme.of(context).textTheme.bodyMedium),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: h.safetyController,
              decoration: InputDecoration(
                hintText: '如果太累不想做完整版，两分钟能做什么？',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  Widget _stepShell({required Widget child}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    );
  }

  Widget _inputDialog(BuildContext ctx, String title, String hint) {
    final controller = TextEditingController();
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// Internal data class for step 4 habit drafts.
class _HabitDraft {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController safetyController = TextEditingController();
  String frequency = 'daily';
  final Set<int> selectedIndices = {};
  List<String> _availableActions = [];

  void setAvailableActions(List<String> actions) {
    _availableActions = actions;
    selectedIndices.removeWhere((i) => i >= actions.length);
  }

  bool isSelected(String action) {
    final i = _availableActions.indexOf(action);
    return i >= 0 && selectedIndices.contains(i);
  }
}
