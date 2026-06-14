import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';

class HabitCreatePage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final int? contextGoalId;

  const HabitCreatePage({
    super.key,
    required this.goalService,
    required this.habitService,
    this.contextGoalId,
  });

  @override
  State<HabitCreatePage> createState() => _HabitCreatePageState();
}

class _HabitCreatePageState extends State<HabitCreatePage> {
  final _nameController = TextEditingController();
  final _twoMinVerController = TextEditingController();
  final _customFreqController = TextEditingController();
  String _frequency = 'daily';
  Set<int> _customDays = {};
  TimeOfDay? _selectedTime;
  List<String> _actionNames = [];
  bool _loading = true;
  bool _saving = false;

  int? _milestoneId;

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
    _loadMilestone();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _twoMinVerController.dispose();
    _customFreqController.dispose();
    super.dispose();
  }

  Future<void> _loadMilestone() async {
    if (widget.contextGoalId == null) {
      setState(() => _loading = false);
      return;
    }
    final milestone =
        await widget.goalService.getActiveMilestone(widget.contextGoalId!);
    if (!mounted) return;
    setState(() {
      _milestoneId = milestone?.id;
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
    if (widget.contextGoalId == null || _milestoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法确定目标里程碑，请从目标面进入')),
      );
      return;
    }

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
        freq = 'custom';
      }

      final actionNames =
          _actionNames.where((n) => n.trim().isNotEmpty).toList();

      final timeStr = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      await widget.habitService.createHabit(
        _milestoneId!,
        name,
        freq,
        actionNames: actionNames,
        twoMinVer: _twoMinVerController.text.trim().isEmpty
            ? null
            : _twoMinVerController.text.trim(),
        customDays: customDaysJson,
        time: timeStr,
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

  String get _timeString =>
      _selectedTime == null ? '' : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

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
                            final weekday = i + 1; // 1=Mon, 7=Sun
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
                      _sectionTitle('习惯时间（可选）'),
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

                      // ── Action Items (habit-level) ──
                      _sectionTitle('行动项（习惯的具体步骤）'),
                      Text(
                        '把习惯拆成具体可执行的步骤',
                        style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(128),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ..._actionNames.asMap().entries.map((entry) {
                        final i = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      TextEditingController(text: entry.value),
                                  decoration: InputDecoration(
                                    hintText: '如：平板支撑 60秒',
                                    border: const OutlineInputBorder(),
                                    prefixText: '${i + 1}. ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => _actionNames[i] = v,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 20, color: Colors.grey.shade400),
                                onPressed: () =>
                                    setState(() => _actionNames.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _actionNames.add('')),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加步骤'),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
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
