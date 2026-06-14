import 'package:flutter/material.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/review_service.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/milestone.dart';
import '../models/review.dart';
import '../models/log_entry.dart';

class ReviewPage extends StatefulWidget {
  final GoalService goalService;
  final HabitService habitService;
  final ReviewService reviewService;

  const ReviewPage({
    super.key,
    required this.goalService,
    required this.habitService,
    required this.reviewService,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<Goal> _goals = [];
  int? _selectedGoalId;
  List<Milestone> _milestones = [];
  Map<int, List<Habit>> _milestoneHabits = {};
  Map<int, Map<String, String?>> _habitWeekStatuses = {};
  String _weekKey = '';
  String _weekLabel = '';
  List<String> _dates = [];
  Review? _existingReview;
  List<Review> _pastReviews = [];
  bool _loading = true;
  int? _expandedReviewId;

  final _q1Controller = TextEditingController();
  final _q2Controller = TextEditingController();
  final _q3Controller = TextEditingController();

  static const _sep = '\n---\n';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final wk = _weekKeyFor(now);
    final label =
        '${monday.month}月${monday.day}日 - ${sunday.month}月${sunday.day}日';

    final dates = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    final goals = await widget.goalService.getActiveGoals();

    int? goalId;
    if (_selectedGoalId != null && goals.any((g) => g.id == _selectedGoalId)) {
      goalId = _selectedGoalId;
    } else if (goals.isNotEmpty) {
      goalId = goals.first.id;
    }

    List<Milestone> milestones = [];
    Map<int, List<Habit>> milestoneHabits = {};
    Map<int, Map<String, String?>> habitWeekStatuses = {};

    if (goalId != null) {
      milestones = await widget.goalService.getMilestonesByGoal(goalId);
      for (final m in milestones) {
        final habits =
            await widget.habitService.getHabitsByMilestone(m.id!);
        milestoneHabits[m.id!] = habits;
        for (final h in habits) {
          final statuses = <String, String?>{};
          final logs = await widget.habitService.getLogsForHabit(h.id!, limit: 7);
          for (final d in dates) {
            for (final l in logs) {
              if (l.date == d) {
                statuses[d] = l.status.value;
              }
            }
            statuses.putIfAbsent(d, () => null);
          }
          habitWeekStatuses[h.id!] = statuses;
        }
      }
    }

    final review =
        await widget.reviewService.getReview(wk, goalId: goalId);
    final past = await widget.reviewService.getAllReviews(goalId: goalId);

    if (!mounted) return;

    setState(() {
      _weekKey = wk;
      _weekLabel = label;
      _dates = dates;
      _goals = goals;
      _selectedGoalId = goalId;
      _milestones = milestones;
      _milestoneHabits = milestoneHabits;
      _habitWeekStatuses = habitWeekStatuses;
      _existingReview = review;
      _pastReviews = past;
      _loading = false;

      if (review?.notes != null) {
        _parseNotes(review!.notes!);
      } else {
        _q1Controller.clear();
        _q2Controller.clear();
        _q3Controller.clear();
      }
    });
  }

  String _weekKeyFor(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}';
  }

  void _parseNotes(String notes) {
    final parts = notes.split(_sep);
    if (parts.length >= 3) {
      _q1Controller.text = parts[0];
      _q2Controller.text = parts[1];
      _q3Controller.text = parts[2];
    }
  }

  Future<void> _saveReview() async {
    final notes =
        '${_q1Controller.text}$_sep${_q2Controller.text}$_sep${_q3Controller.text}';
    await widget.reviewService.saveReview(
      _weekKey,
      goalId: _selectedGoalId,
      notes: notes,
    );

    final past =
        await widget.reviewService.getAllReviews(goalId: _selectedGoalId);
    if (!mounted) return;

    setState(() => _pastReviews = past);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回顾已保存'), duration: Duration(seconds: 1)),
    );
  }

  bool _isCompleted(String? status) =>
      status == 'two_min' || status == 'full';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('每周回顾'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGoalSelector(colorScheme),
                    const SizedBox(height: 16),
                    _buildWeekHeader(colorScheme),
                    const SizedBox(height: 24),
                    _buildHabitGrid(colorScheme),
                    const SizedBox(height: 24),
                    _buildReflectionQuestions(colorScheme),
                    const SizedBox(height: 16),
                    _buildSaveButton(colorScheme),
                    const SizedBox(height: 24),
                    _buildPastReviews(colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGoalSelector(ColorScheme colorScheme) {
    if (_goals.length <= 1) {
      if (_goals.isEmpty) {
        return Text('暂无目标',
            style: TextStyle(color: colorScheme.onSurface.withAlpha(128)));
      }
      return Row(children: [
        Icon(Icons.flag_outlined, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(_goals.first.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
    }
    return DropdownButton<int>(
      value: _selectedGoalId,
      isExpanded: true,
      items: _goals
          .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
          .toList(),
      onChanged: (id) {
        if (id != null) {
          setState(() {
            _selectedGoalId = id;
            _loading = true;
          });
          _loadData();
        }
      },
    );
  }

  Widget _buildWeekHeader(ColorScheme colorScheme) {
    const dow = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本周', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(_weekLabel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(7, (i) {
                final date = DateTime.parse(_dates[i]);
                return Expanded(
                  child: Column(children: [
                    Text(dow[i], style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('${date.month}/${date.day}', style: const TextStyle(fontSize: 11)),
                  ]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitGrid(ColorScheme colorScheme) {
    // Flatten all habits from all milestones
    final allHabits = <Habit>[];
    for (final m in _milestones) {
      allHabits.addAll(_milestoneHabits[m.id] ?? []);
    }

    if (allHabits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('暂无活跃习惯', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('习惯完成情况',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: allHabits.map((habit) {
                final statuses = _habitWeekStatuses[habit.id] ?? {};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                      width: 80,
                      child: Text(habit.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis, maxLines: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(7, (i) {
                          final status = statuses[_dates[i]];
                          final done = _isCompleted(status);
                          final isTwoMin = status == 'two_min';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: done
                                        ? (isTwoMin ? Colors.orange : colorScheme.primary)
                                        : status == 'skipped'
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReflectionQuestions(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('反思问题',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                controller: _q1Controller,
                decoration: const InputDecoration(
                  labelText: '哪些习惯做起来很自然？',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q2Controller,
                decoration: const InputDecoration(
                  labelText: '哪些习惯你一直躲着？障碍在哪？',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q3Controller,
                decoration: const InputDecoration(
                  labelText: '下周你打算调整什么？',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _saveReview,
        icon: Icon(_existingReview != null ? Icons.edit : Icons.save),
        label: Text(_existingReview != null ? '更新回顾' : '保存回顾'),
      ),
    );
  }

  Widget _buildPastReviews(ColorScheme colorScheme) {
    if (_pastReviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('历史回顾',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        const SizedBox(height: 8),
        Column(
          children: _pastReviews.map((review) {
            final isExpanded = _expandedReviewId == review.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () =>
                    setState(() => _expandedReviewId = isExpanded ? null : review.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(review.week,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: colorScheme.onSurfaceVariant),
                      ]),
                      if (review.notes != null && review.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          review.notes!.length > 50 && !isExpanded
                              ? '${review.notes!.substring(0, 50)}...'
                              : review.notes!.replaceAll(_sep, '\n\n'),
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
