import 'package:flutter/material.dart';

/// 统计项 — 一个大号数字 + 标签。
///
/// [value] 为显示的数字（前缀），[label] 为下方标签文字。
/// 支持可选的 [valueStyle] / [labelStyle] 自定义样式。
class StatItem {
  final String value;
  final String label;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  const StatItem({
    required this.value,
    required this.label,
    this.valueStyle,
    this.labelStyle,
  });
}

/// 统计数字行 — 等宽多列展示统计项。
///
/// 参数：
///   [items] — 统计项列表。
///   [spacing] — 列间距，默认 16。
///   [valueStyle] — 默认数字样式（可被 [StatItem.valueStyle] 覆盖）。
///   [labelStyle] — 默认标签样式（可被 [StatItem.labelStyle] 覆盖）。
///
/// 示例：
/// ```dart
/// StatsRow(
///   items: [
///     const StatItem(value: '3', label: '习惯'),
///     const StatItem(value: '1', label: '目标'),
///     const StatItem(value: '7', label: '天'),
///   ],
/// )
/// ```
class StatsRow extends StatelessWidget {
  final List<StatItem> items;
  final double spacing;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  const StatsRow({
    super.key,
    required this.items,
    this.spacing = 16,
    this.valueStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveLabelStyle = labelStyle ??
        TextStyle(
          fontSize: 11,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        );
    final effectiveValueStyle = valueStyle ??
        const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2);

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].value,
                  style: items[i].valueStyle ?? effectiveValueStyle,
                ),
                Text(
                  items[i].label,
                  style: items[i].labelStyle ?? effectiveLabelStyle,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
