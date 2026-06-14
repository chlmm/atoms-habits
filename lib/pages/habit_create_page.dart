import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../models/action_plan.dart';

class HabitCreatePage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final int? milestoneId;

  const HabitCreatePage({
    super.key,
    required this.goalService,
    required this.habitService,
    this.milestoneId,
  });

  @override
  State<HabitCreatePage> createState() => _HabitCreatePageState();
}

class _HabitCreatePageState extends State<HabitCreatePage> {
  final _nameController = TextEditingController();
  final _twoMinVerController = TextEditingController();
  final _customFreqController = TextEditingController();
  String _frequency = 'daily';
  List<ActionPlan> _availableActions = [];
  Set<int> _selectedActionIds = {};
  bool _loading = true;
  bool _saving = false;

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
    _loadActions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _twoMinVerController.dispose();
    _customFreqController.dispose();
    super.dispose();
  }

  Future<void> _loadActions() async {
    if (widget.milestoneId == null) {
      setState(() => _loading = false);
      return;
    }
    final actions =
        await widget.goalService.getActionPlansByMilestone(widget.milestoneId!);
    if (!mounted) return;
    setState(() {
      _availableActions = actions;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入习惯名称')),
      );
      return;
    }
    if (widget.milestoneId == null) return;

    setState(() => _saving = true);
    try {
      String freq = _frequency;
      if (_frequency == 'custom') {
        final custom = _customFreqController.text.trim();
        if (custom.isEmpty) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入自定义频率')),
          );
          return;
        }
        freq = custom;
      }
      await widget.habitService.createHabit(
        widget.milestoneId!,
        name,
        freq,
        actionPlanIds: _selectedActionIds.toList(),
        twoMinVer: _twoMinVerController.text.trim().isEmpty
            ? null
            : _twoMinVerController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('新建习惯'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Name ──
                      _sectionTitle('习惯名称'),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: '如：练背计划',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Frequency ──
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
                      if (_frequency == 'custom') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customFreqController,
                          decoration: const InputDecoration(
                            hintText: '如：每三天 / 每月两次',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // ── Action Plans ──
                      _sectionTitle('从行动计划中挑选'),
                      if (_availableActions.isEmpty)
                        Text(
                          '当前里程碑没有行动计划，可直接创建。',
                          style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(128)),
                        )
                      else
                        ..._availableActions.map((a) => CheckboxListTile(
                              value: _selectedActionIds.contains(a.id),
                              title: Text(a.name),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              dense: true,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedActionIds.add(a.id!);
                                  } else {
                                    _selectedActionIds.remove(a.id!);
                                  }
                                });
                              },
                            )),
                      const SizedBox(height: 20),

                      // ── Two-min safety valve ──
                      _sectionTitle('两分钟安全阀'),
                      Text(
                        '如果太累不想做完整版，两分钟能做什么？',
                        style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(128),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _twoMinVerController,
                        decoration: const InputDecoration(
                          hintText: '如：挂上单杠 30秒',
                          border: OutlineInputBorder(),
                        ),
                      ),
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
            : const Text('创建习惯', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
