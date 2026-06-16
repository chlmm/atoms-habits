import 'package:flutter/material.dart';

/// 信息行 — 图标 + 标題 + 可选副标题，带边框圆角容器。
///
/// 适用于展示只读关联信息（如父级习惯、所属里程碑等）。
///
/// 参数：
///   [icon]      — 图标，如 `Icons.flag_outlined`。
///   [iconColor] — 图标颜色。
///   [label]     — 标题文字。
///   [subtitle]  — 可选副标题。
///   [padding]   — 内边距，默认 `EdgeInsets.symmetric(horizontal: 12, vertical: 12)`。
///   [borderRadius] — 圆角，默认 8。
///
/// 示例：
/// ```dart
/// InfoRow(
///   icon: Icons.flag_outlined,
///   iconColor: Colors.blue,
///   label: '所属目标',
///   subtitle: '每周跑步 3 次',
/// )
/// ```
class InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const InfoRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
