import 'package:flutter/material.dart';
import '../services/frequency_service.dart';
import '../models/habit.dart';
import '../models/log_entry.dart';

/// 近两周日程条 — 展示过去 7 天 + 未来 7 天的习惯状态。
///
/// 参数：
///   [habit]            — 习惯对象（用于训练日判断）。
///   [recentStatuses]   — Map<dateStr, status>，日期 → 状态码。
///   [allLogs]          — 全部打卡日志。
///   [frequencyService] — 频率服务（用于训练日判断）。
///   [title]            — 标题，默认 "近两周日程"。
///   [referenceDate]    — 参考日期，默认今天。
class WeekStrip extends StatelessWidget {
  final Habit? habit;
  final Map<String, String?> recentStatuses;
  final List<LogEntry> allLogs;
  final FrequencyService frequencyService;
  final String title;
  final DateTime referenceDate;

  WeekStrip({
    super.key,
    required this.frequencyService,
    this.habit,
    this.recentStatuses = const {},
    this.allLogs = const [],
    this.title = '近两周日程',
    DateTime? referenceDate,
  }) : referenceDate = referenceDate ?? DateTime.now();

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];
  static const _totalDays = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                _legend(Colors.green, '已完成'),
                _legend(Colors.orange, '两分钟版'),
                _legend(Colors.grey, '已跳过'),
                _legend(colorScheme.primary.withValues(alpha: 0.3), '训练日'),
                _legend(Colors.grey.shade200, '休息日'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_totalDays, (i) {
                final offset = i - 7;
                final date = referenceDate.add(Duration(days: offset));
                final dateStr = _dateKey(date);
                final status = recentStatuses[dateStr];
                final isFull = status == 'full';
                final isTwoMin = status == 'two_min';
                final isSkipped = status == 'skipped';
                final isToday = offset == 0;
                final isFuture = offset > 0;

                final isTrainingDay = habit != null &&
                    frequencyService.isTrainingDayForDate(
                        habit!, allLogs, date);

                Color bgColor;
                Widget? icon;
                Color borderColor = Colors.transparent;
                double borderWidth = 0;

                if (isFull) {
                  bgColor = Colors.green;
                  icon = const Icon(Icons.check,
                      color: Colors.white, size: 14);
                } else if (isTwoMin) {
                  bgColor = Colors.orange;
                  icon = const Icon(Icons.check,
                      color: Colors.white, size: 14);
                } else if (isSkipped) {
                  bgColor = Colors.grey.shade400;
                  icon = const Icon(Icons.close,
                      color: Colors.white, size: 12);
                } else if (isTrainingDay) {
                  bgColor = colorScheme.primary.withValues(alpha: 0.15);
                  icon = isFuture
                      ? Icon(Icons.fiber_manual_record,
                          size: 8,
                          color: colorScheme.primary.withValues(alpha: 0.5))
                      : null;
                } else {
                  bgColor = Colors.grey.shade200;
                }

                if (isToday) {
                  borderColor = colorScheme.primary;
                  borderWidth = 2;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                        border: borderWidth > 0
                            ? Border.all(
                                color: borderColor, width: borderWidth)
                            : null,
                      ),
                      child: Center(child: icon),
                    ),
                    const SizedBox(height: 3),
                    Text(date.day.toString(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.bold : null,
                            color: isFuture ? colorScheme.outline : null)),
                    Text(_dayNames[date.weekday - 1],
                        style: TextStyle(
                            fontSize: 9,
                            color: isTrainingDay
                                ? colorScheme.primary
                                : colorScheme.outline
                                    .withValues(alpha: 0.5))),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
