import '../services/goal_service.dart';
import '../services/habit_service.dart';

/// Inserts the "双力臂" demo dataset for onboarding and testing.
/// Uses services, not AppDatabase directly.
Future<void> insertDemoData({
  required GoalService goalService,
  required HabitService habitService,
}) async {
  // 1. Create goal
  final goal = await goalService.createGoal('完成双力臂');

  // 2. Create 4 milestones
  await goalService.createMilestone(goal.id!, '完成 1 个引体向上',
      targetDesc: '标准正手引体向上 1 次', targetValue: 1);
  await goalService.createMilestone(goal.id!, '完成 10 个标准引体',
      targetDesc: '标准引体向上 10 次', targetValue: 10);
  await goalService.createMilestone(goal.id!, '完成 10 个变体引体',
      targetDesc: '宽距/窄距/反手等变体', targetValue: 10);
  await goalService.createMilestone(goal.id!, '完成 1 个双力臂',
      targetDesc: '标准双力臂 1 次', targetValue: 1);

  // 3. Get active milestone
  final m1 = await goalService.getActiveMilestone(goal.id!);

  // 4. Create habits with their own action plans
  await habitService.createHabit(
    m1!.id!,
    '练背计划',
    'every_other',
    actionNames: [
      '负重悬吊 30秒',
      '弹力带辅助引体 5×3',
      '离心引体下降 5×3',
      '拉伸 30秒',
    ],
    twoMinVer: '挂上单杠 30秒',
  );

  await habitService.createHabit(
    m1.id!,
    '核心训练',
    'twice_week',
    actionNames: [
      '平板支撑 60秒',
      '死虫式 3×10',
    ],
    twoMinVer: '平板支撑 20秒',
  );
}
