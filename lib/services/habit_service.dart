import 'dart:convert';
import '../db/database.dart';
import '../models/habit.dart';
import '../models/log_entry.dart';
import '../models/action_plan.dart';

class HabitService {
  final AppDatabase _db;

  HabitService(this._db);

  AppDatabase get db => _db;

  // ── Habit CRUD ───────────────────────────────────────

  Future<Habit> createHabit(
    int milestoneId,
    String name,
    String frequency, {
    List<String>? actionNames,
    String? twoMinVer,
    String? frequencyDesc,
  }) async {
    final habit = Habit(
      milestoneId: milestoneId,
      name: name,
      frequency: frequency,
      twoMinVer: twoMinVer,
      frequencyDesc: frequencyDesc,
    );
    final id = await _db.insertHabit(habit);
    final created = habit.copyWith(id: id);

    if (actionNames != null && actionNames.isNotEmpty) {
      for (var i = 0; i < actionNames.length; i++) {
        await createActionPlan(id, actionNames[i], sortOrder: i);
      }
    }

    return created;
  }

  Future<Habit?> getHabit(int id) => _db.getHabit(id);

  Future<List<Habit>> getHabitsByMilestone(int milestoneId,
          {bool includeArchived = false}) =>
      _db.getHabitsByMilestone(milestoneId, includeArchived: includeArchived);

  Future<Habit> updateHabit(Habit h) async {
    await _db.updateHabit(h);
    return h;
  }

  Future<void> deleteHabit(int id) => _db.deleteHabit(id);

  Future<void> archiveHabit(int id) => _db.archiveHabit(id);

  // ── Action Plans (habit-level) ────────────────────────

  Future<ActionPlan> createActionPlan(
    int habitId,
    String name, {
    int sortOrder = 0,
  }) async {
    final ap = ActionPlan(
      habitId: habitId,
      name: name,
      sortOrder: sortOrder,
    );
    final id = await _db.insertActionPlan(ap);
    return ap.copyWith(id: id);
  }

  Future<List<ActionPlan>> getActionPlansForHabit(int habitId) =>
      _db.getActionPlansForHabit(habitId);

  Future<void> deleteActionPlan(int id) => _db.deleteActionPlan(id);

  Future<void> deleteActionPlansForHabit(int habitId) =>
      _db.deleteActionPlansForHabit(habitId);

  // ── Logging ──────────────────────────────────────────

  Future<LogEntry> completeHabit(
    int habitId, {
    String status = 'full',
    Map<String, bool>? actionCompletions,
    String? note,
    String? date,
  }) async {
    final targetDate = date ?? _db.today();
    final existing = await _db.getLogForDate(habitId, targetDate);

    String? actionCompletionsJson;
    if (actionCompletions != null) {
      actionCompletionsJson = jsonEncode(actionCompletions);
    }

    final entry = LogEntry(
      id: existing?.id,
      habitId: habitId,
      date: targetDate,
      status: LogStatusExt.fromString(status),
      actionCompletions: actionCompletionsJson,
      note: note,
    );

    if (existing != null) {
      await _db.updateLog(entry);
    } else {
      final id = await _db.insertLog(entry);
      return entry.copyWith(id: id);
    }

    return entry;
  }

  Future<LogEntry> skipHabit(int habitId, {String? note, String? date}) async {
    return completeHabit(habitId, status: 'skipped', note: note, date: date);
  }

  Future<LogEntry?> getLogToday(int habitId) =>
      _db.getLogForDate(habitId, _db.today());

  Future<List<LogEntry>> getLogsForHabit(int habitId, {int limit = 365}) =>
      _db.getLogsForHabit(habitId, limit: limit);

  Future<int> getTotalCompletedCount(int habitId) =>
      _db.getTotalCompletedCount(habitId);

  Future<Map<String, String>> getRecentStatuses(int habitId, int days) =>
      _db.getRecentStatuses(habitId, days);

  // ── Utility ──────────────────────────────────────────

  String today() => _db.today();

  // ── Drawer Stats / Heatmap data ──────────────────────

  /// Aggregate check-in counts per day across all active habits.
  Future<Map<String, int>> getDailyCheckinCounts({
    required String startDate,
    required String endDate,
  }) => _db.getDailyCheckinCounts(startDate: startDate, endDate: endDate);

  /// Count of distinct days with at least one check-in.
  Future<int> getActiveDaysCount({
    required String startDate,
    required String endDate,
  }) => _db.getActiveDaysCount(startDate: startDate, endDate: endDate);

  /// Total count of active (non-archived) habits.
  Future<int> getActiveHabitCount() async {
    final habits = await _db.getAllHabits(includeArchived: false);
    return habits.length;
  }

  /// 获取某天所有活跃习惯的打卡状态。
  Future<List<Map<String, dynamic>>> getHabitsWithStatusForDate(String date) =>
      _db.getHabitsWithStatusForDate(date);

  /// Total completed check-ins across all active habits.
  Future<int> getTotalCheckinCount() async {
    final habits = await _db.getAllHabits(includeArchived: false);
    int total = 0;
    for (final h in habits) {
      total += await getTotalCompletedCount(h.id!);
    }
    return total;
  }
}
