import 'package:flutter/material.dart';

/// 习惯状态图标 — 40x40 圆形状态指示器。
///
/// 四种状态：
///   - [StatusIconType.completed] → 绿色底 + check_circle
///   - [StatusIconType.twoMin]    → 橙色底 + check_circle_outline
///   - [StatusIconType.skipped]   → 灰色底 + cancel_outlined
///   - [StatusIconType.pending]   → 灰色底 + circle_outlined
///
/// [greyedOut] 仅对 pending 状态生效，使图标更淡。
enum StatusIconType { completed, twoMin, skipped, pending }

class StatusIcon extends StatelessWidget {
  final StatusIconType type;
  final bool greyedOut;
  final double size;

  const StatusIcon({
    super.key,
    required this.type,
    this.greyedOut = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (type) {
      case StatusIconType.completed:
        bg = Colors.green.shade50;
        fg = Colors.green;
        icon = Icons.check_circle;
      case StatusIconType.twoMin:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade600;
        icon = Icons.check_circle_outline;
      case StatusIconType.skipped:
        bg = Colors.grey.shade100;
        fg = Colors.grey;
        icon = Icons.cancel_outlined;
      case StatusIconType.pending:
        bg = Colors.grey.shade100;
        fg = greyedOut ? Colors.grey.shade300 : Colors.grey.shade400;
        icon = Icons.circle_outlined;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: fg, size: size * 0.7),
    );
  }
}
