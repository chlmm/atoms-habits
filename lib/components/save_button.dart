import 'package:flutter/material.dart';

/// 全宽保存按钮 — 支持加载状态和可选图标。
///
/// 参数：
///   [label]    — 按钮文字。
///   [onPressed]— 点击回调。
///   [isSaving] — 是否保存中（显示加载指示器）。
///   [icon]     — 可选图标。
class SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isSaving;
  final IconData? icon;

  const SaveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isSaving = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isSaving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, style: const TextStyle(fontSize: 16));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: icon != null
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: child,
            ),
    );
  }
}
