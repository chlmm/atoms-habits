import 'package:flutter/material.dart';

/// 分组标题 — 带下间距的粗体文字，用于表单/设置页分段。
///
/// 参数：
///   [title]   — 标题文字。
///   [padding] — 外边距，默认 `EdgeInsets.only(bottom: 8)`。
///
/// 示例：
/// ```dart
/// SectionTitle('基本信息')
/// SectionTitle('通知设置', padding: EdgeInsets.only(bottom: 12, top: 16))
/// ```
class SectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionTitle(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
