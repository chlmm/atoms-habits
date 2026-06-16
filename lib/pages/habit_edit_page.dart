import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../models/habit.dart';
import '../models/action_plan.dart';
import '../components/save_button.dart';
import '../components/section_title.dart';

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
  Set<int> _customDays = {};
  TimeOfDay? _selectedTime;
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

  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
      _customDays = habit.customDaysSet;
      if (habit.time != null) {
        final parts = habit.time!.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
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
      String freq = _frequency;
      String? customDaysJson;
      if (_frequency == 'custom') {
        if (_customDays.isEmpty) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('自定义频率请至少选择一天')),
          );
          return;
        }
        customDaysJson = jsonEncode(_customDays.toList()..sort());
      }

      final timeStr = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      // Update habit fields
      final updated = _habit!.copyWith(
        name: name,
        frequency: freq,
        customDays: customDaysJson,
        time: timeStr,
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

  String get _timeString =>
      _selectedTime == null ? '' : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

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
                      SectionTitle('习惯名称'),
                      TextField(controller: _nameController),
                      const SizedBox(height: 20),

                      SectionTitle('频率'),
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

                      // ── Custom: 周日历选择 ──
                      if (_frequency == 'custom') ...[
                        const SizedBox(height: 8),
                        Text('选择每周哪几天',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withAlpha(128),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (i) {
                            final weekday = i + 1;
                            final selected = _customDays.contains(weekday);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (selected) {
                                  _customDays.remove(weekday);
                                } else {
                                  _customDays.add(weekday);
                                }
                              }),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                ),
                                child: Center(
                                  child: Text(
                                    _dayLabels[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface.withAlpha(128),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // ── Time ──
                      SectionTitle('习惯时间（可选）'),
                      Text(
                        '设定后，自动生成的待办将携带此时间',
                        style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(128),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime ?? TimeOfDay.now(),
                          );
                          if (picked != null && mounted) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 10),
                              Text(
                                _timeString.isEmpty ? '选择时间' : _timeString,
                                style: TextStyle(
                                  color: _timeString.isEmpty
                                      ? colorScheme.onSurface.withValues(alpha: 0.4)
                                      : null,
                                ),
                              ),
                              if (_selectedTime != null) ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _selectedTime = null),
                                  child: Icon(Icons.close, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Action Items ──
                      SectionTitle('行动项'),
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

                      SectionTitle('两分钟安全阀'),
                      TextField(controller: _twoMinVerController),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                SaveButton(label: '保存', onPressed: _saving ? null : _save, isSaving: _saving),
              ],
            ),
    );
  }

}
