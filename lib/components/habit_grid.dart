import 'package:flutter/material.dart';
import '../models/habit.dart';

/// 习惯完成情况网格 — 展示每个习惯在 7 天内的每日状态。
///
/// 参数：
///   [habits]            — 习惯列表。
///   [habitWeekStatuses] — Map<habitId, Map<dateStr, status>>。
///   [dates]             — 7 个日期字符串（YYYY-MM-DD），从左到右。
///   [title]             — 标题，默认 "习惯完成情况"。
class HabitGrid extends StatelessWidget {
  final List<Habit> habits;
  final Map<int, Map<String, String?>> habitWeekStatuses;
  final List<String> dates;
  final String title;

  const HabitGrid({
    super.key,
    required this.habits,
    required this.habitWeekStatuses,
    required this.dates,
    this.title = '习惯完成情况',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (habits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('暂无活跃习惯',
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: habits.map((habit) {
                final statuses = habitWeekStatuses[habit.id] ?? {};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                      width: 80,
                      child: Text(habit.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(dates.length, (i) {
                          final status = statuses[dates[i]];
                          final done = _isCompleted(status);
                          final isTwoMin = status == 'two_min';
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: done
                                        ? (isTwoMin
                                            ? Colors.orange
                                            : colorScheme.primary)
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

  static bool _isCompleted(String? status) =>
      status == 'two_min' || status == 'full';
}
