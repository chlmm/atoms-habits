import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services.dart';

/// 抽屉所需统计数据
class DrawerData {
  final int habitCount;
  final int goalCount;
  final int activeDays;
  final Map<String, int> dailyCounts;

  const DrawerData({
    required this.habitCount,
    required this.goalCount,
    required this.activeDays,
    required this.dailyCounts,
  });
}

/// 抽屉数据 Provider — 热力图 + 统计数字。
///
/// 调用 ref.invalidate(drawerDataProvider) 强制刷新。
final drawerDataProvider = FutureProvider.autoDispose<DrawerData>((ref) async {
  final habitService = ref.read(habitServiceProvider);
  final goalService = ref.read(goalServiceProvider);

  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final startDate = now.subtract(const Duration(days: 130));
  final startStr =
      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

  final results = await Future.wait([
    habitService.getActiveHabitCount(),
    goalService.getAllGoals(),
    habitService.getDailyCheckinCounts(startDate: startStr, endDate: todayStr),
    habitService.getActiveDaysCount(startDate: startStr, endDate: todayStr),
  ]);

  return DrawerData(
    habitCount: results[0] as int,
    goalCount: (results[1] as List).length,
    dailyCounts: results[2] as Map<String, int>,
    activeDays: results[3] as int,
  );
});
