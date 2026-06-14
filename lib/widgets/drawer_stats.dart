import 'package:flutter/material.dart';

/// Drawer 统计数字行 — 3列大号数字 (习惯数 / 目标数 / 活跃天数)
///
/// 数据由外部通过 [habitCount], [goalCount], [activeDays] 传入，
/// 由 MainPage 从 HabitService/GoalService 获取后传递。
class DrawerStats extends StatelessWidget {
  final int habitCount;
  final int goalCount;
  final int activeDays;

  const DrawerStats({
    super.key,
    required this.habitCount,
    required this.goalCount,
    required this.activeDays,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
        fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5));
    final numberStyle = const TextStyle(
        fontSize: 28, fontWeight: FontWeight.bold, height: 1.2);

    return Row(
      children: [
        Expanded(child: _statItem('$habitCount', '习惯', numberStyle, labelStyle)),
        Expanded(child: _statItem('$goalCount', '目标', numberStyle, labelStyle)),
        Expanded(child: _statItem('$activeDays', '天', numberStyle, labelStyle)),
      ],
    );
  }

  Widget _statItem(String num, String label, TextStyle numStyle, TextStyle labelStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num, style: numStyle),
        Text(label, style: labelStyle),
      ],
    );
  }
}
