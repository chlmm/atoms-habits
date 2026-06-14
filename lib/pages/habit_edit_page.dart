import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../models/habit.dart';
import '../models/action_plan.dart';

class HabitEditPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final int habitId;

  const HabitEditPage({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.habitId,
  });

  @override
  State<HabitEditPage> createState() => _HabitEditPageState();
}

class _HabitEditPageState extends State<HabitEditPage> {
  final _nameController = TextEditingController();
  final _twoMinVerController = TextEditingController();
  String _frequency = 'daily';
  List<ActionPlan> _actions = [];
  bool _loading = true;
  bool _saving = false;
  Habit? _habit;

  static const _frequencies = [
    ('daily', '每天'),
    ('every_other', '每两天'),
    ('twice_week', '每周两次'),
    ('weekly', '每周'),
    ('custom', '自定义'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _twoMinVerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final habit = await widget.habitService.getHabit(widget.habitId);
    if (habit == null || !mounted) {
      setState(() => _loading = false);
      return;
    }

    final actions =
        await widget.habitService.getActionPlansForHabit(habit.id!);

    setState(() {
      _habit = habit;
      _nameController.text = habit.name;
      _twoMinVerController.text = habit.twoMinVer ?? '';
      _frequency = habit.frequency;
      _actions = actions;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_habit == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Update habit fields
      final updated = _habit!.copyWith(
        name: name,
        frequency: _frequency,
        twoMinVer: _twoMinVerController.text.trim().isEmpty
            ? null
            : _twoMinVerController.text.trim(),
      );
      await widget.habitService.updateHabit(updated);

      // Rebuild action plans: delete all + re-insert
      await widget.habitService.deleteActionPlansForHabit(_habit!.id!);
      for (var i = 0; i < _actions.length; i++) {
        final a = _actions[i];
        if (a.name.trim().isNotEmpty) {
          await widget.habitService.createActionPlan(
            _habit!.id!, a.name.trim(),
            sortOrder: i,
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveHabit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('归档习惯'),
        content: const Text('归档后不再显示，但数据保留。确认？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.habitService.archiveHabit(widget.habitId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑习惯'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '归档',
            onPressed: _archiveHabit,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionTitle('习惯名称'),
                      TextField(controller: _nameController),
                      const SizedBox(height: 20),

                      _sectionTitle('频率'),
                      Wrap(
                        spacing: 8,
                        children: _frequencies.map((f) {
                          final selected = _frequency == f.$1;
                          return ChoiceChip(
                            label: Text(f.$2),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _frequency = f.$1),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // ── Action Items ──
                      _sectionTitle('行动项'),
                      ..._actions.asMap().entries.map((entry) {
                        final i = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(
                                      text: entry.value.name),
                                  decoration: InputDecoration(
                                    hintText: '步骤名称',
                                    border: const OutlineInputBorder(),
                                    prefixText: '${i + 1}. ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) =>
                                      _actions[i] = _actions[i].copyWith(name: v),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 20, color: Colors.grey.shade400),
                                onPressed: () =>
                                    setState(() => _actions.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () => setState(() => _actions.add(
                            ActionPlan(habitId: _habit?.id ?? 0, name: ''))),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加步骤'),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _sectionTitle('两分钟安全阀'),
                      TextField(controller: _twoMinVerController),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                _buildSaveButton(colorScheme),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('保存', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
