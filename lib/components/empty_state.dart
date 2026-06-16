import 'package:flutter/material.dart';

/// 空状态占位组件 — 居中图标 + 提示文字 + 可选操作按钮。
///
/// 适用于列表为空、无搜索结果、无通知等场景。
///
/// 参数：
///   [icon]    — 图标，如 `Icons.inbox_outlined`。
///   [message] — 提示文字，支持多行。
///   [action]  — 可选的操作按钮（如 "创建"）。
///   [iconSize]— 图标大小，默认 64。
///
/// 示例：
/// ```dart
/// EmptyState(
///   icon: Icons.inbox_outlined,
///   message: '还没有数据。\n点击下方按钮开始吧！',
///   action: OutlinedButton.icon(
///     onPressed: () {},
///     icon: const Icon(Icons.add),
///     label: const Text('创建'),
///   ),
/// )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: colorScheme.onSurface.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
