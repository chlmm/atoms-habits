import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../db/database.dart';
import '../data/demo_data.dart';
import 'goal_service.dart';
import 'habit_service.dart';
import 'review_service.dart';
import 'identity_service.dart';
import '../models/identity_insight.dart';
import '../pages/main_page.dart';

class CliService {
  final AppDatabase _db;
  final GoalService _goalService;
  final HabitService _habitService;
  final ReviewService _reviewService;
  final GlobalKey<MainPageState>? _mainPageKey;
  final GlobalKey<NavigatorState>? _navigatorKey;

  ServerSocket? _server;
  final List<Socket> _clients = [];
  final DateTime _startTime = DateTime.now();

  CliService({
    required AppDatabase db,
    required GoalService goalService,
    required HabitService habitService,
    required ReviewService reviewService,
    GlobalKey<MainPageState>? mainPageKey,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _db = db,
        _goalService = goalService,
        _habitService = habitService,
        _reviewService = reviewService,
        _mainPageKey = mainPageKey,
        _navigatorKey = navigatorKey;

  Future<void> start({int port = 9999}) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((socket) {
      _clients.add(socket);
      _handleConnection(socket);
    });
  }

  Future<void> stop() async {
    for (final client in _clients) {
      try {
        client.destroy();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close();
  }

  void _handleConnection(Socket socket) {
    socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) => _handleCommand(socket, line),
          onError: (_) => _removeClient(socket),
          onDone: () => _removeClient(socket),
        );
  }

  void _removeClient(Socket socket) {
    _clients.remove(socket);
    try {
      socket.destroy();
    } catch (_) {}
  }

  Future<void> _handleCommand(Socket socket, String line) async {
    try {
      final cmd = jsonDecode(line) as Map<String, dynamic>;
      final result = await _route(cmd['cmd'] as String, cmd);
      _respond(socket, {'status': 'ok', 'data': result});
    } catch (e) {
      _respond(socket, {'status': 'error', 'message': e.toString()});
    }
  }

  void _respond(Socket socket, Map<String, dynamic> response) {
    try {
      socket.write('${jsonEncode(response)}\n');
      socket.flush();
    } catch (_) {
      _removeClient(socket);
    }
  }

  Future<dynamic> _route(String command, Map<String, dynamic> params) async {
    switch (command) {
      // ── Base commands (R1) ──
      case 'ping':
        return _handlePing();
      case 'get_db_stats':
        return _handleGetDbStats();
      case 'reset_db':
        return _handleResetDb();
      case 'shutdown':
        return _handleShutdown();

      // ── Data commands (R2) ──
      case 'insert_demo_data':
        return _handleInsertDemoData();
      case 'create_goal':
        return _handleCreateGoal(params);
      case 'create_milestone':
        return _handleCreateMilestone(params);
      case 'create_action_plan':
        return _handleCreateActionPlan(params);
      case 'create_habit':
        return _handleCreateHabit(params);
      case 'get_goals':
        return _handleGetGoals();
      case 'get_milestones':
        return _handleGetMilestones(params);
      case 'get_action_plans':
        return _handleGetActionPlans(params);
      case 'get_habits':
        return _handleGetHabits(params);

      // ── Navigation commands (R3) ──
      case 'nav':
        return _handleNav(params);
      case 'switch_face':
        return _handleSwitchFace(params);
      case 'switch_goal':
        return _handleSwitchGoal(params);
      case 'navigate_back':
        return _handleNavigateBack();
      case 'get_current_state':
        return _handleGetCurrentState();

      // ── Habit execution commands (R4) ──
      case 'complete_habit':
        return _handleCompleteHabit(params);
      case 'skip_habit':
        return _handleSkipHabit(params);
      case 'get_logs_today':
        return _handleGetLogsToday(params);
      case 'get_logs_week':
        return _handleGetLogsWeek(params);
      case 'get_total_completed':
        return _handleGetTotalCompleted(params);
      case 'get_habit':
        return _handleGetHabit(params);
      case 'archive_habit':
        return _handleArchiveHabit(params);

      // ── Milestone commands (R5) ──
      case 'update_milestone':
        return _handleUpdateMilestone(params);
      case 'complete_milestone':
        return _handleCompleteMilestone(params);
      case 'get_goal_progress':
        return _handleGetGoalProgress(params);

      // ── Review commands (R6) ──
      case 'save_review':
        return _handleSaveReview(params);
      case 'get_reviews':
        return _handleGetReviews(params);

      // ── Identity commands (R7) ──
      case 'get_identity_insights':
        return _handleGetIdentityInsights(params);
      case 'check_identity_triggers':
        return _handleCheckIdentityTriggers(params);
      case 'create_identity_insight':
        return _handleCreateIdentityInsight(params);
      case 'accept_identity_insight':
        return _handleAcceptIdentityInsight(params);

      default:
        throw Exception('unknown command: $command');
    }
  }

  // ══════════════════════════════════════════════════════
  // Base handlers (R1)
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handlePing() async {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': DateTime.now().difference(_startTime).inSeconds,
    };
  }

  Future<Map<String, dynamic>> _handleGetDbStats() async {
    return _db.getTableStats();
  }

  Future<Map<String, dynamic>> _handleResetDb() async {
    await _db.resetAllData();
    return {'reset': true};
  }

  Future<Map<String, dynamic>> _handleShutdown() async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 200));
    exit(0);
  }

  // ══════════════════════════════════════════════════════
  // R2 data handlers
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handleInsertDemoData() async {
    await insertDemoData(
      goalService: _goalService,
      habitService: _habitService,
    );
    return {'inserted': true};
  }

  Future<Map<String, dynamic>> _handleCreateGoal(Map<String, dynamic> p) async {
    final name = p['name'] as String;
    final goal = await _goalService.createGoal(name);
    return goal.toMap();
  }

  Future<Map<String, dynamic>> _handleCreateMilestone(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int;
    final name = p['name'] as String;
    final targetDesc = p['target_desc'] as String?;
    final targetValue = (p['target_value'] as num?)?.toDouble();
    final m = await _goalService.createMilestone(goalId, name,
        targetDesc: targetDesc, targetValue: targetValue);
    return m.toMap();
  }

  Future<Map<String, dynamic>> _handleCreateActionPlan(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final name = p['name'] as String;
    final ap = await _habitService.createActionPlan(habitId, name);
    return ap.toMap();
  }

  Future<Map<String, dynamic>> _handleCreateHabit(
      Map<String, dynamic> p) async {
    final milestoneId = p['milestone_id'] as int;
    final name = p['name'] as String;
    final frequency = p['frequency'] as String? ?? 'daily';
    final actionNames = (p['action_names'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    final twoMinVer = p['two_min_ver'] as String?;
    final h = await _habitService.createHabit(
      milestoneId, name, frequency,
      actionNames: actionNames,
      twoMinVer: twoMinVer,
    );
    return h.toMap();
  }

  Future<List<Map<String, dynamic>>> _handleGetGoals() async {
    final goals = await _goalService.getAllGoals();
    return goals.map((g) => g.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _handleGetMilestones(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int;
    final ms = await _goalService.getMilestonesByGoal(goalId);
    return ms.map((m) => m.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _handleGetActionPlans(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final aps = await _habitService.getActionPlansForHabit(habitId);
    return aps.map((a) => a.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _handleGetHabits(
      Map<String, dynamic> p) async {
    final milestoneId = p['milestone_id'] as int;
    final habits = await _habitService.getHabitsByMilestone(milestoneId);
    return habits.map((h) => h.toMap()).toList();
  }

  // ══════════════════════════════════════════════════════
  // R3 navigation handlers
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handleNav(Map<String, dynamic> p) async {
    final route = p['route'] as String;
    _mainPageKey?.currentState?.cliNavigate(route);
    return {'navigated': route};
  }

  Future<Map<String, dynamic>> _handleSwitchFace(
      Map<String, dynamic> p) async {
    final face = p['face'] as String;
    _mainPageKey?.currentState?.cliSwitchFace(face);
    return {'face': face};
  }

  Future<Map<String, dynamic>> _handleSwitchGoal(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int;
    _mainPageKey?.currentState?.cliSwitchGoal(goalId);
    return {'active_goal_id': goalId};
  }

  Future<Map<String, dynamic>> _handleNavigateBack() async {
    _navigatorKey?.currentState?.pop();
    return {'navigated_back': true};
  }

  Future<Map<String, dynamic>> _handleGetCurrentState() async {
    final mainState = _mainPageKey?.currentState;
    final goals = await _goalService.getActiveGoals();
    final activeGoalId = mainState?.activeGoalId;
    List<Map<String, dynamic>> milestonesStatus = [];

    if (activeGoalId != null) {
      final ms = await _goalService.getMilestonesByGoal(activeGoalId);
      milestonesStatus = ms
          .map((m) => {
                'id': m.id,
                'name': m.name,
                'status': m.status,
              })
          .toList();
    }

    return {
      'current_face': mainState?.currentFace ?? 'unknown',
      'active_goal_id': activeGoalId,
      'current_route': _navigatorKey?.currentState?.widget.toString() ?? 'unknown',
      'goals_count': goals.length,
      'milestones_status': milestonesStatus,
    };
  }

  // ══════════════════════════════════════════════════════
  // R4 habit execution handlers
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handleCompleteHabit(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final status = p['status'] as String? ?? 'full';
    final date = p['date'] as String?;
    final actionCompletions = (p['action_completions'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as bool));
    final log = await _habitService.completeHabit(
      habitId,
      status: status,
      actionCompletions: actionCompletions,
      date: date,
    );
    return log.toMap();
  }

  Future<Map<String, dynamic>> _handleSkipHabit(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final date = p['date'] as String?;
    final log = await _habitService.skipHabit(habitId, date: date);
    return log.toMap();
  }

  Future<dynamic> _handleGetLogsToday(Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final log = await _habitService.getLogToday(habitId);
    return log?.toMap();
  }

  Future<List<Map<String, dynamic>>> _handleGetLogsWeek(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final logs = await _habitService.getLogsForHabit(habitId, limit: 7);
    return logs.map((l) => l.toMap()).toList();
  }

  Future<Map<String, dynamic>> _handleGetTotalCompleted(
      Map<String, dynamic> p) async {
    final habitId = p['habit_id'] as int;
    final count = await _habitService.getTotalCompletedCount(habitId);
    return {'count': count};
  }

  Future<Map<String, dynamic>?> _handleGetHabit(
      Map<String, dynamic> p) async {
    final habitId = p['id'] as int;
    final habit = await _habitService.getHabit(habitId);
    if (habit == null) return null;
    final actions = await _habitService.getActionPlansForHabit(habitId);
    final map = habit.toMap();
    map['action_plans'] = actions.map((a) => a.toMap()).toList();
    return map;
  }

  Future<Map<String, dynamic>> _handleArchiveHabit(
      Map<String, dynamic> p) async {
    final habitId = p['id'] as int;
    await _habitService.archiveHabit(habitId);
    return {'id': habitId, 'archived': true};
  }

  // ══════════════════════════════════════════════════════
  // R5 milestone handlers
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handleUpdateMilestone(
      Map<String, dynamic> p) async {
    final id = p['id'] as int;
    final currentValue = (p['current_value'] as num?)?.toDouble();
    final m = await _goalService.getMilestone(id);
    if (m == null) throw Exception('milestone not found');
    final updated = m.copyWith(currentValue: currentValue);
    await _goalService.updateMilestone(updated);
    return updated.toMap();
  }

  Future<Map<String, dynamic>> _handleCompleteMilestone(
      Map<String, dynamic> p) async {
    final id = p['id'] as int;
    await _goalService.completeMilestone(id);
    return {'id': id, 'status': 'completed'};
  }

  Future<Map<String, dynamic>> _handleGetGoalProgress(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int;
    final progress = await _goalService.getGoalProgress(goalId);
    // Ensure all values are JSON-serializable
    return {
      'total_milestones': progress['total_milestones'],
      'completed_milestones': progress['completed_milestones'],
      'progress_percent': progress['progress_percent'],
    };
  }

  // ══════════════════════════════════════════════════════
  // R6 review handlers
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _handleSaveReview(
      Map<String, dynamic> p) async {
    final week = p['week'] as String;
    final goalId = p['goal_id'] as int?;
    final notes = p['notes'] as String?;
    final review = await _reviewService.saveReview(week,
        goalId: goalId, notes: notes);
    return review.toMap();
  }

  Future<List<Map<String, dynamic>>> _handleGetReviews(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int?;
    final reviews = await _reviewService.getAllReviews(goalId: goalId);
    return reviews.map((r) => r.toMap()).toList();
  }

  // ══════════════════════════════════════════════════════
  // R7 identity handlers
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _handleGetIdentityInsights(
      Map<String, dynamic> p) async {
    final goalId = p['goal_id'] as int?;
    final identityService = IdentityService(_db);
    final insights = await identityService.getInsights(goalId: goalId);
    return insights.map((i) => i.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _handleCheckIdentityTriggers(
      Map<String, dynamic> p) async {
    final identityService = IdentityService(_db);
    return await identityService.checkTriggers();
  }

  Future<Map<String, dynamic>> _handleCreateIdentityInsight(
      Map<String, dynamic> p) async {
    final text = p['text'] as String;
    final goalId = p['goal_id'] as int?;
    final triggeredBy = p['triggered_by'] as String?;
    final identityService = IdentityService(_db);
    final insight = IdentityInsight(
      text: text,
      goalId: goalId,
      triggeredBy: triggeredBy,
    );
    final created = await identityService.createInsight(insight);
    return created.toMap();
  }

  Future<Map<String, dynamic>> _handleAcceptIdentityInsight(
      Map<String, dynamic> p) async {
    final id = p['id'] as int;
    final identityService = IdentityService(_db);
    final updated = await identityService.acceptInsight(id);
    return updated.toMap();
  }
}
