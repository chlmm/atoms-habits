import '../db/database.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/action_plan.dart';

class GoalService {
  final AppDatabase _db;

  GoalService(this._db);

  // ── Goals ────────────────────────────────────────────

  Future<Goal> createGoal(String name) async {
    final goal = Goal(name: name, status: 'active');
    final id = await _db.insertGoal(goal);
    return goal.copyWith(id: id);
  }

  Future<Goal?> getGoal(int id) => _db.getGoal(id);

  Future<List<Goal>> getAllGoals() => _db.getAllGoals();

  Future<List<Goal>> getActiveGoals() => _db.getActiveGoals();

  Future<Goal> updateGoal(Goal goal) async {
    await _db.updateGoal(goal);
    return goal;
  }

  Future<void> deleteGoal(int id) => _db.deleteGoal(id);

  Future<void> completeGoal(int id) async {
    final goal = await _db.getGoal(id);
    if (goal == null) return;
    await _db.updateGoal(goal.copyWith(status: 'completed'));
  }

  Future<void> archiveGoal(int id) async {
    await _db.updateGoal(Goal(id: id, name: '', status: 'archived'));
  }

  // ── Milestones ───────────────────────────────────────

  Future<Milestone> createMilestone(
    int goalId,
    String name, {
    String? targetDesc,
    double? targetValue,
  }) async {
    // Determine sort order
    final existingCount = await _db.getMilestoneCount(goalId);
    // First milestone is automatically active
    final status = existingCount == 0 ? 'active' : 'waiting';

    final m = Milestone(
      goalId: goalId,
      name: name,
      sortOrder: existingCount,
      status: status,
      targetDesc: targetDesc,
      targetValue: targetValue,
    );
    final id = await _db.insertMilestone(m);
    return m.copyWith(id: id);
  }

  Future<Milestone?> getMilestone(int id) => _db.getMilestone(id);

  Future<List<Milestone>> getMilestonesByGoal(int goalId) =>
      _db.getMilestonesByGoal(goalId);

  Future<Milestone?> getActiveMilestone(int goalId) =>
      _db.getActiveMilestone(goalId);

  Future<Milestone> updateMilestone(Milestone m) async {
    await _db.updateMilestone(m);
    return m;
  }

  Future<void> deleteMilestone(int id) => _db.deleteMilestone(id);

  Future<void> completeMilestone(int id) async {
    final m = await _db.getMilestone(id);
    if (m == null) return;

    final now = DateTime.now().toIso8601String();
    await _db.updateMilestone(m.copyWith(
      status: 'completed',
      completedAt: now,
    ));

    // Activate the next milestone for the same goal
    final allMilestones = await _db.getMilestonesByGoal(m.goalId);
    final currentIndex = allMilestones.indexWhere((x) => x.id == m.id);
    if (currentIndex >= 0 && currentIndex < allMilestones.length - 1) {
      final next = allMilestones[currentIndex + 1];
      await _db.updateMilestone(next.copyWith(status: 'active'));
    }

    // Check if all milestones completed → complete goal
    final remaining = allMilestones.where((x) => x.id != m.id).toList();
    if (remaining.every((x) => x.status == 'completed')) {
      await completeGoal(m.goalId);
    }
  }

  // ── Action Plans ─────────────────────────────────────

  Future<ActionPlan> createActionPlan(
    int milestoneId,
    String name, {
    int sortOrder = 0,
  }) async {
    final ap = ActionPlan(
      milestoneId: milestoneId,
      name: name,
      sortOrder: sortOrder,
    );
    final id = await _db.insertActionPlan(ap);
    return ap.copyWith(id: id);
  }

  Future<List<ActionPlan>> getActionPlansByMilestone(int milestoneId) =>
      _db.getActionPlansByMilestone(milestoneId);

  Future<void> deleteActionPlan(int id) => _db.deleteActionPlan(id);

  // ── Combined Queries ─────────────────────────────────

  Future<Map<String, dynamic>> getGoalProgress(int goalId) async {
    final goal = await _db.getGoal(goalId);
    final milestones = await _db.getMilestonesByGoal(goalId);

    int totalMilestones = milestones.length;
    int completedMilestones =
        milestones.where((m) => m.status == 'completed').length;
    double progressPercent =
        totalMilestones > 0 ? completedMilestones / totalMilestones * 100 : 0;

    return {
      'goal': goal?.toMap(),
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'total_milestones': totalMilestones,
      'completed_milestones': completedMilestones,
      'progress_percent': progressPercent,
    };
  }
}
