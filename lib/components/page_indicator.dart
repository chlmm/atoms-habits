import 'package:flutter/material.dart';

/// PageView 圆点指示器 — 带动画切换的页码指示器。
///
/// 参数：
///   [currentPage]  — 当前页索引。
///   [totalPages]   — 总页数。
///   [onDotTap]     — 点击圆点回调 (index)。
///   [activeColor]  — 当前页颜色，默认主题色 primary。
///   [inactiveColor]— 非当前页颜色，默认 outline + 30% 透明度。
class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final void Function(int index)? onDotTap;
  final Color? activeColor;
  final Color? inactiveColor;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onDotTap,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ??
        colorScheme.outline.withValues(alpha: 0.3);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
            final isActive = index == currentPage;
            return GestureDetector(
              onTap: onDotTap != null ? () => onDotTap!(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? active : inactive,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
