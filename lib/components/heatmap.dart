import 'package:flutter/material.dart';

/// GitHub 风格贡献热力图。
///
/// 参数：
///   [dailyCounts] - 每日数据，key 为 'YYYY-MM-DD'，value 为该日计数。
///   [colorScheme] - 配色方案。
///   [onDayTap] - 点击格子回调 (date, count)。仅 count > 0 的格子可点。
///   [weeks] - 显示的周数，默认 18。
///   [isDark] - 强制明暗模式（默认从 colorScheme 推导）。
///   [tooltipBuilder] - 自定义 tooltip (date, count) → String。
class Heatmap extends StatelessWidget {
  final Map<String, int> dailyCounts;
  final ColorScheme colorScheme;
  final void Function(String date, int count)? onDayTap;
  final int weeks;
  final bool? isDark;
  final String Function(String date, int count)? tooltipBuilder;

  const Heatmap({
    super.key,
    required this.dailyCounts,
    required this.colorScheme,
    this.onDayTap,
    this.weeks = 18,
    this.isDark,
    this.tooltipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    const daysPerWeek = 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final start = weekStart.subtract(Duration(days: (weeks - 1) * daysPerWeek));

    final maxCount = dailyCounts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final dark = isDark ?? (colorScheme.brightness == Brightness.dark);
    final primary = colorScheme.primary;

    Color colorFor(int c) {
      if (c <= 0) {
        return dark ? const Color(0xFF262626) : Colors.black.withValues(alpha: 0.05);
      }
      final t = maxCount <= 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);
      if (t <= 0.25) return primary.withValues(alpha: dark ? 0.28 : 0.18);
      if (t <= 0.5) return primary.withValues(alpha: dark ? 0.48 : 0.35);
      if (t <= 0.75) return primary.withValues(alpha: dark ? 0.68 : 0.55);
      return primary.withValues(alpha: dark ? 0.9 : 0.85);
    }

    // Build cells: row=weekday, col=week
    final cells = <DateTime>[];
    for (var row = 0; row < daysPerWeek; row++) {
      for (var col = 0; col < weeks; col++) {
        cells.add(start.add(Duration(days: col * daysPerWeek + row)));
      }
    }

    final labelColor = colorScheme.onSurface.withValues(alpha: 0.35);
    final mid = start.add(Duration(days: (weeks * daysPerWeek) ~/ 2));
    final end = start.add(Duration(days: (weeks * daysPerWeek) - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: weeks,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: weeks * daysPerWeek,
          itemBuilder: (context, index) {
            final day = cells[index];
            if (day.isAfter(today)) return const SizedBox.shrink();

            final key = _dateKey(day);
            final count = dailyCounts[key] ?? 0;
            final color = colorFor(count);
            final tip = tooltipBuilder?.call(key, count) ?? _defaultTooltip(key, count);

            return Tooltip(
              message: tip,
              triggerMode: TooltipTriggerMode.longPress,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(2),
                  onTap: count > 0 && onDayTap != null
                      ? () => onDayTap!(key, count)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      border: day == today
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
            Text(_monthLabel(start),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
            Text(_monthLabel(mid),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
            Text(_monthLabel(end),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
          ],
        ),
      ],
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime d) {
    const names = ['', '1月', '2月', '3月', '4月', '5月', '6月',
        '7月', '8月', '9月', '10月', '11月', '12月'];
    return names[d.month];
  }

  static String _defaultTooltip(String date, int count) =>
      '$date: ${count > 0 ? '$count' : '—'}';
}
