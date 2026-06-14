import 'package:flutter/material.dart';

/// Drawer 热力图 — MemoFlow 风格 GitHub 贡献图
///
/// 数据由外部通过 [dailyCounts] 传入 (Map<String, int>),
/// key 为 'YYYY-MM-DD' 日期字符串, value 为当天打卡次数。
/// 由 MainPage 从 HabitService.getDailyCheckinCounts() 获取后传递。
class DrawerHeatmap extends StatelessWidget {
  final Map<String, int> dailyCounts;
  final ColorScheme colorScheme;

  /// 点击某天格子的回调，参数为日期字符串 'YYYY-MM-DD' 和打卡次数。
  /// 只有 count > 0 的格子才会触发此回调。
  final void Function(String date, int count)? onDayTap;

  const DrawerHeatmap({
    super.key,
    required this.dailyCounts,
    required this.colorScheme,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // ── Grid config: 18 weeks × 7 days ──
    const weeks = 18;
    const daysPerWeek = 7;

    // ── Date range: align to week boundary (Monday start) ──
    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);
    final currentWeekStart = todayLocal.subtract(
      Duration(days: todayLocal.weekday - 1),
    );
    final alignedStart = currentWeekStart.subtract(
      Duration(days: (weeks - 1) * daysPerWeek),
    );

    // ── Color scaling based on max count ──
    final maxCount = dailyCounts.values.fold<int>(0, (max, v) => v > max ? v : max);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = colorScheme.primary;

    Color colorFor(int c) {
      if (c <= 0) {
        return isDark
            ? const Color(0xFF262626)
            : Colors.black.withValues(alpha: 0.05);
      }
      final t = maxCount <= 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);
      if (t <= 0.25) return primary.withValues(alpha: isDark ? 0.28 : 0.18);
      if (t <= 0.5) return primary.withValues(alpha: isDark ? 0.48 : 0.35);
      if (t <= 0.75) return primary.withValues(alpha: isDark ? 0.68 : 0.55);
      return primary.withValues(alpha: isDark ? 0.9 : 0.85);
    }

    // ── Build cell list: row=weekday (Mon=0..Sun=6), col=week ──
    final cells = <DateTime>[];
    for (var row = 0; row < daysPerWeek; row++) {
      for (var col = 0; col < weeks; col++) {
        cells.add(alignedStart.add(Duration(days: col * daysPerWeek + row)));
      }
    }

    // ── Month labels (3 positions: start / mid / end) ──
    final labelColor = colorScheme.onSurface.withValues(alpha: 0.35);
    final mid = alignedStart.add(
      Duration(days: (weeks * daysPerWeek) ~/ 2),
    );
    final late = alignedStart.add(
      Duration(days: (weeks * daysPerWeek) - 1),
    );

    String _monthLabel(DateTime d) {
      const names = ['', '1月', '2月', '3月', '4月', '5月', '6月',
                        '7月', '8月', '9月', '10月', '11月', '12月'];
      return names[d.month];
    }

    String _dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: weeks,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: weeks * daysPerWeek,
          itemBuilder: (context, index) {
            final day = cells[index];
            if (day.isAfter(todayLocal)) {
              return const SizedBox.shrink();
            }
            final count = dailyCounts[_dateKey(day)] ?? 0;
            final isToday = day == todayLocal;
            final color = colorFor(count);
            final dateKey = _dateKey(day);
            return Tooltip(
              message:
                  '$dateKey: ${count > 0 ? '$count 次打卡' : '无打卡'}',
              triggerMode: TooltipTriggerMode.longPress,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(2),
                  onTap: count > 0 && onDayTap != null
                      ? () => onDayTap!(dateKey, count)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      border: isToday
                          ? Border.all(color: primary, width: 1.5)
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_monthLabel(alignedStart),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
            Text(_monthLabel(mid),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
            Text(_monthLabel(late),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
          ],
        ),
      ],
    );
  }
}
