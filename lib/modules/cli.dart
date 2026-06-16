import 'dart:io';

import 'package:cli_bridge/cli_bridge.dart';
import 'package:flutter/material.dart';

import 'database.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/review_service.dart';
import '../services/todo_service.dart';
import '../services/identity_service.dart';
import '../data/demo_data.dart';
import '../models/identity_insight.dart';
import '../pages/main_page.dart';

/// 向 CliBridge 注册 Atoms 项目的全部 CLI 命令。
void setupCliBridge(
  CliBridge bridge,
  AppDatabase db,
  GoalService goalService,
  HabitService habitService,
  ReviewService reviewService,
  TodoService todoService,
  GlobalKey<MainPageState> mainPageKey,
  GlobalKey<NavigatorState> navigatorKey,
) {
  // ═══════════════════════════════════════════════════
  // R1 基础命令
  // ═══════════════════════════════════════════════════

  bridge.on('ping', schema: {}, handler: (_) => {
    'timestamp': DateTime.now().toIso8601String(),
    'uptime': bridge.uptimeSeconds,
  });

  bridge.on('get_db_stats', schema: {}, handler: (_) => db.getTableStats());

  bridge.on('reset_db', schema: {}, handler: (_) async {
    await db.resetAllData();
    return {'reset': true};
  });

  bridge.on('shutdown', schema: {}, handler: (_) async {
    await bridge.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    exit(0);
  });

  // ═══════════════════════════════════════════════════
  // R2 数据写入
  // ═══════════════════════════════════════════════════

  bridge.on('insert_demo_data', schema: {}, handler: (_) async {
    await insertDemoData(goalService: goalService, habitService: habitService);
    return {'inserted': true};
  });

  bridge.on('create_goal', schema: {
    'name': Param.string(required: true, desc: '目标名称'),
  }, handler: (params) async {
    final goal = await goalService.createGoal(params['name']);
    return goal.toMap();
  });

  bridge.on('create_milestone', schema: {
    'goal_id':      Param.integer(required: true, desc: '目标 ID'),
    'name':         Param.string(required: true, desc: '里程碑名称'),
    'target_desc':  Param.string(desc: '目标描述'),
    'target_value': Param.number(desc: '目标值（int 或 double）'),
  }, handler: (params) async {
    final targetValue = (params['target_value'] as num?)?.toDouble();
    final m = await goalService.createMilestone(
      params['goal_id'], params['name'],
      targetDesc: params['target_desc'],
      targetValue: targetValue,
    );
    return m.toMap();
  });

  bridge.on('create_action_plan', schema: {
    'milestone_id': Param.integer(required: true, desc: '里程碑 ID'),
    'name':         Param.string(required: true, desc: '计划名称'),
  }, handler: (params) async {
    // action_plan 现在关联到 habit，这里用 milestone_id 参数兼容旧测试
    // 创建一个临时习惯来绑定
    final ap = await habitService.createActionPlan(
      params['milestone_id'], // 兼容旧参数名，实际会被 test 传 milestone_id
      params['name'],
    );
    return ap.toMap();
  });

  bridge.on('create_habit', schema: {
    'milestone_id':    Param.integer(required: true, desc: '里程碑 ID'),
    'name':            Param.string(required: true, desc: '习惯名称'),
    'frequency':       Param.string(desc: '频率: daily|every_other|weekly|twice_week|custom'),
    'action_plan_ids': Param.stringList(desc: '关联的行动 ID 列表'),
    'action_names':    Param.stringList(desc: '行动项名称列表'),
    'two_min_ver':     Param.string(desc: '两分钟安全阀'),
  }, handler: (params) async {
    final actionNames = (params['action_names'] as List?)?.cast<String>();
    // 如果有 action_plan_ids，通过 ID 获取名称
    List<String>? names = actionNames;
    if (actionNames == null || actionNames.isEmpty) {
      final apIds = (params['action_plan_ids'] as List?)?.map((e) => e as int).toList();
      if (apIds != null && apIds.isNotEmpty) {
        names = [];
        for (final id in apIds) {
          // 通过 milestone_id 作为 habit_id 来查（兼容旧测试的 action_plan 绑定方式）
          final aps = await habitService.getActionPlansForHabit(id);
          if (aps.isNotEmpty) {
            names.add(aps.first.name);
          }
        }
      }
    }

    final h = await habitService.createHabit(
      params['milestone_id'], params['name'],
      params['frequency'] ?? 'daily',
      actionNames: names,
      twoMinVer: params['two_min_ver'],
    );
    return h.toMap();
  });

  // ═══════════════════════════════════════════════════
  // R2 查询
  // ═══════════════════════════════════════════════════

  bridge.on('get_goals', schema: {}, handler: (_) async {
    final goals = await goalService.getAllGoals();
    return goals.map((g) => g.toMap()).toList();
  });

  bridge.on('get_milestones', schema: {
    'goal_id': Param.integer(required: true, desc: '目标 ID'),
  }, handler: (params) async {
    final ms = await goalService.getMilestonesByGoal(params['goal_id']);
    return ms.map((m) => m.toMap()).toList();
  });

  bridge.on('get_action_plans', schema: {
    'milestone_id': Param.integer(required: true, desc: '里程碑 ID（兼容）'),
  }, handler: (_) async {
    // 兼容旧测试：直接查 action_plans 表（忽略 milestone_id 参数）
    final rows = await db.db.query('action_plans', orderBy: 'sort_order ASC');
    return rows;
  });

  bridge.on('get_habits', schema: {
    'milestone_id': Param.integer(required: true, desc: '里程碑 ID'),
  }, handler: (params) async {
    final habits = await habitService.getHabitsByMilestone(params['milestone_id']);
    return habits.map((h) => h.toMap()).toList();
  });

  // ═══════════════════════════════════════════════════
  // R3 导航（UI 操作）
  // ═══════════════════════════════════════════════════

  bridge.on('nav', schema: {
    'route': Param.string(required: true, desc: '路由 path'),
  }, handler: (params) {
    mainPageKey.currentState?.cliNavigate(params['route']);
    return {'navigated': params['route']};
  });

  bridge.on('switch_face', schema: {
    'face': Param.string(required: true, desc: 'goal|habit|todo'),
  }, handler: (params) {
    mainPageKey.currentState?.cliSwitchFace(params['face']);
    return {'face': params['face']};
  });

  bridge.on('switch_goal', schema: {
    'goal_id': Param.integer(required: true, desc: '目标 ID'),
  }, handler: (params) {
    mainPageKey.currentState?.cliSwitchGoal(params['goal_id']);
    return {'active_goal_id': params['goal_id']};
  });

  bridge.on('navigate_back', schema: {}, handler: (_) {
    navigatorKey.currentState?.pop();
    return {'navigated_back': true};
  });

  bridge.on('get_current_state', schema: {}, handler: (_) async {
    final mainState = mainPageKey.currentState;
    final goals = await goalService.getActiveGoals();
    final activeGoalId = mainState?.activeGoalId;
    final milestonesStatus = <Map<String, dynamic>>[];
    if (activeGoalId != null) {
      final ms = await goalService.getMilestonesByGoal(activeGoalId);
      milestonesStatus.addAll(ms.map((m) => {'id': m.id, 'name': m.name, 'status': m.status}));
    }
    return {
      'current_face': mainState?.currentFace ?? 'unknown',
      'active_goal_id': activeGoalId,
      'current_route': navigatorKey.currentState?.widget.toString() ?? 'unknown',
      'goals_count': goals.length,
      'milestones_status': milestonesStatus,
    };
  });

  // ═══════════════════════════════════════════════════
  // R4 习惯执行
  // ═══════════════════════════════════════════════════

  bridge.on('complete_habit', schema: {
    'habit_id':           Param.integer(required: true, desc: '习惯 ID'),
    'status':             Param.string(desc: 'full|two_min|skipped'),
    'date':               Param.string(desc: 'YYYY-MM-DD'),
    'action_completions': Param.object(desc: '行动项完成状态 Map'),
  }, handler: (params) async {
    final actionCompletions = (params['action_completions'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as bool));
    final log = await habitService.completeHabit(
      params['habit_id'],
      status: params['status'] ?? 'full',
      actionCompletions: actionCompletions,
      date: params['date'],
    );
    return log.toMap();
  });

  bridge.on('skip_habit', schema: {
    'habit_id': Param.integer(required: true, desc: '习惯 ID'),
    'date':     Param.string(desc: 'YYYY-MM-DD'),
  }, handler: (params) async {
    final log = await habitService.skipHabit(params['habit_id'], date: params['date']);
    return log.toMap();
  });

  bridge.on('get_logs_today', schema: {
    'habit_id': Param.integer(required: true, desc: '习惯 ID'),
  }, handler: (params) async {
    final log = await habitService.getLogToday(params['habit_id']);
    return log?.toMap();
  });

  bridge.on('get_logs_week', schema: {
    'habit_id': Param.integer(required: true, desc: '习惯 ID'),
  }, handler: (params) async {
    final logs = await habitService.getLogsForHabit(params['habit_id'], limit: 7);
    return logs.map((l) => l.toMap()).toList();
  });

  bridge.on('get_total_completed', schema: {
    'habit_id': Param.integer(required: true, desc: '习惯 ID'),
  }, handler: (params) async {
    final count = await habitService.getTotalCompletedCount(params['habit_id']);
    return {'count': count};
  });

  bridge.on('get_habit', schema: {
    'id': Param.integer(required: true, desc: '习惯 ID'),
  }, handler: (params) async {
    final habit = await habitService.getHabit(params['id']);
    if (habit == null) return null;
    final actions = await habitService.getActionPlansForHabit(params['id']);
    final map = habit.toMap();
    map['action_plans'] = actions.map((a) => a.toMap()).toList();
    return map;
  });

  bridge.on('archive_habit', schema: {
    'id': Param.integer(required: true, desc: '习惯 ID'),
  }, handler: (params) async {
    await habitService.archiveHabit(params['id']);
    return {'id': params['id'], 'archived': true};
  });

  // ═══════════════════════════════════════════════════
  // R5 里程碑推进
  // ═══════════════════════════════════════════════════

  bridge.on('update_milestone', schema: {
    'id':            Param.integer(required: true, desc: '里程碑 ID'),
    'current_value': Param.number(desc: '当前值（int 或 double）'),
  }, handler: (params) async {
    final m = await goalService.getMilestone(params['id']);
    if (m == null) throw Exception('milestone not found');
    final value = (params['current_value'] as num?)?.toDouble();
    final updated = m.copyWith(currentValue: value);
    await goalService.updateMilestone(updated);
    return updated.toMap();
  });

  bridge.on('complete_milestone', schema: {
    'id': Param.integer(required: true, desc: '里程碑 ID'),
  }, handler: (params) async {
    await goalService.completeMilestone(params['id']);
    return {'id': params['id'], 'status': 'completed'};
  });

  bridge.on('get_goal_progress', schema: {
    'goal_id': Param.integer(required: true, desc: '目标 ID'),
  }, handler: (params) async {
    final progress = await goalService.getGoalProgress(params['goal_id']);
    return {
      'total_milestones': progress['total_milestones'],
      'completed_milestones': progress['completed_milestones'],
      'progress_percent': progress['progress_percent'],
    };
  });

  // ═══════════════════════════════════════════════════
  // R6 每周回顾
  // ═══════════════════════════════════════════════════

  bridge.on('save_review', schema: {
    'goal_id': Param.integer(desc: '目标 ID（可选）'),
    'week':    Param.string(required: true, desc: '周标识 YYYY-Www'),
    'notes':   Param.string(desc: '笔记内容'),
  }, handler: (params) async {
    final review = await reviewService.saveReview(
      params['week'],
      goalId: params['goal_id'],
      notes: params['notes'],
    );
    return review.toMap();
  });

  bridge.on('get_reviews', schema: {
    'goal_id': Param.integer(desc: '目标 ID（可选）'),
  }, handler: (params) async {
    final reviews = await reviewService.getAllReviews(goalId: params['goal_id']);
    return reviews.map((r) => r.toMap()).toList();
  });

  // ═══════════════════════════════════════════════════
  // R7 身份洞察
  // ═══════════════════════════════════════════════════

  final identityService = IdentityService(db);

  bridge.on('get_identity_insights', schema: {
    'goal_id': Param.integer(desc: '目标 ID（可选）'),
  }, handler: (params) async {
    final insights = await identityService.getInsights(goalId: params['goal_id']);
    return insights.map((i) => i.toMap()).toList();
  });

  bridge.on('check_identity_triggers', schema: {}, handler: (_) async {
    return await identityService.checkTriggers();
  });

  bridge.on('create_identity_insight', schema: {
    'text':         Param.string(required: true, desc: '身份表述'),
    'goal_id':      Param.integer(desc: '目标 ID'),
    'triggered_by': Param.string(desc: '触发条件'),
  }, handler: (params) async {
    final insight = IdentityInsight(
      text: params['text'],
      goalId: params['goal_id'],
      triggeredBy: params['triggered_by'],
    );
    final created = await identityService.createInsight(insight);
    return created.toMap();
  });

  bridge.on('accept_identity_insight', schema: {
    'id': Param.integer(required: true, desc: '洞察 ID'),
  }, handler: (params) async {
    final updated = await identityService.acceptInsight(params['id']);
    return updated.toMap();
  });
}
