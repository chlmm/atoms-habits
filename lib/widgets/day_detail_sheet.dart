import 'package:flutter/material.dart';
import '../services/habit_service.dart';

/// 热力图日期点击后弹出的底部弹窗 —— 展示当天所有习惯的打卡状态。
///
/// 布局：
/// ┌──────────────────────────────────┐
/// │  6月10日 周三                  ✕  │
/// │  ─────────────────────────────── │
/// │  3/5 习惯已完成   [===●  ] 60%  │
/// │                                  │
/// │  ✓  早起            已完成       │
/// │  ⏱  冥想            两分钟版     │
/// │  ⟶  跑步            已跳过       │
/// │  ✗  写日记           未打卡       │
/// └──────────────────────────────────┘

class DayDetailSheet extends StatefulWidget {
  final String date; // YYYY-MM-DD
  final HabitService habitService;

  const DayDetailSheet({
    super.key,
    required this.date,
    required this.habitService,
  });

  /// 便捷方法：弹出此 sheet
  static Future<void> show(
    BuildContext context, {
    required String date,
    required HabitService habitService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayDetailSheet(date: date, habitService: habitService),
    );
  }

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  List<Map<String, dynamic>> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data =
          await widget.habitService.getHabitsWithStatusForDate(widget.date);
      if (!mounted) return;
      setState(() {
        _habits = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 解析日期
    final parts = widget.date.split('-');
    final dateObj = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    const weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateLabel = '${dateObj.month}月${dateObj.day}日 周${weekDays[dateObj.weekday - 1]}';

    // 统计
    final total = _habits.length;
    final completed = _habits.where((h) {
      final s = h['log_status'] as String?;
      return s == 'full' || s == 'two_min';
    }).length;
    final ratio = total > 0 ? completed / total : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── 拖拽指示条 ──
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── 标题行：日期 + 关闭按钮 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  Text(dateLabel,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── 进度摘要 ──
            if (total > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text('$completed/$total 习惯已完成',
                        style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const Spacer(),
                    Text('${(ratio * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? colorScheme.onSurface.withValues(alpha: 0.1)
                        : colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio >= 1.0
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],

            const Divider(height: 1),

            // ── 习惯列表 ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _habits.isEmpty
                      ? Center(
                          child: Text('暂无活跃习惯',
                              style: TextStyle(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4))))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _habits.length,
                          itemBuilder: (context, index) {
                            return _habitTile(
                                _habits[index], colorScheme, isDark);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _habitTile(Map<String, dynamic> h, ColorScheme colorScheme, bool isDark) {
    final status = h['log_status'] as String?;
    final name = h['name'] as String;

    // 状态图标、颜色、标签
    IconData icon;
    Color iconColor;
    String label;
    Color labelColor;

    switch (status) {
      case 'full':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        label = '已完成';
        labelColor = Colors.green;
        break;
      case 'two_min':
        icon = Icons.timelapse;
        iconColor = Colors.orange;
        label = '两分钟版';
        labelColor = Colors.orange;
        break;
      case 'skipped':
        icon = Icons.skip_next;
        iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        label = '已跳过';
        labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        break;
      default:
        icon = Icons.radio_button_unchecked;
        iconColor = colorScheme.onSurface.withValues(alpha: 0.2);
        label = '未打卡';
        labelColor = colorScheme.onSurface.withValues(alpha: 0.35);
    }

    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(name,
          style: TextStyle(
              fontSize: 14,
              fontWeight: status != null ? FontWeight.w500 : FontWeight.normal,
              color: status == null
                  ? colorScheme.onSurface.withValues(alpha: 0.45)
                  : null)),
      trailing: Text(label,
          style: TextStyle(fontSize: 12, color: labelColor)),
      dense: true,
    );
  }
}
