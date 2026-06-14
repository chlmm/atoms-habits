import '../models/habit.dart';
import '../models/log_entry.dart';

/// Frequency engine that determines which habits should appear
/// as training/reviewable on a given date.
///
/// Pure logic — no DB access. Takes habit + log history as input.
class FrequencyService {
  /// Returns the target number of executions per week for a given frequency.
  static int weeklyTarget(String frequency, {Set<int>? customDays}) {
    switch (frequency) {
      case 'daily':
        return 7;
      case 'every_other':
        return 4;
      case 'weekly':
        return 1;
      case 'twice_week':
        return 2;
      case 'custom':
        return customDays?.length ?? 1;
      default:
        return 7;
    }
  }

  /// Returns the human-readable frequency label.
  static String frequencyLabel(String f) {
    switch (f) {
      case 'daily':
        return '每天';
      case 'every_other':
        return '每两天';
      case 'weekly':
        return '每周';
      case 'twice_week':
        return '每周两次';
      default:
        return f;
    }
  }

  // ── Training day detection ────────────────────────────

  /// Synchronous check: is today a training day for this habit?
  ///
  /// - daily → always true
  /// - every_other → true if last full/two_min was NOT yesterday
  /// - weekly → true if this week has < 1 completion
  /// - twice_week → true if this week has < 2 completions
  /// - custom → treated as daily
  bool isTrainingDaySync(Habit habit, List<LogEntry> logs) {
    final now = DateTime.now();
    final today = _dateKey(now);

    final freq = habit.frequencyEnum;

    switch (freq) {
      case HabitFrequency.daily:
        return true;

      case HabitFrequency.everyOther:
        return _isTrainingDayEveryOther(logs, today);

      case HabitFrequency.weekly:
        return _isTrainingDayWeekly(logs, now);

      case HabitFrequency.twiceWeek:
        return _isTrainingDayWeekly(logs, now, target: 2);

      case HabitFrequency.custom:
        return _isTrainingDayCustom(habit, now);
    }
  }

  /// 判断指定日期是否为训练日。
  /// 用于在详情页展示未来/过去的训练日安排。
  bool isTrainingDayForDate(Habit habit, List<LogEntry> logs, DateTime date) {
    final dateStr = _dateKey(date);
    final freq = habit.frequencyEnum;

    switch (freq) {
      case HabitFrequency.daily:
        return true;

      case HabitFrequency.everyOther:
        return _isTrainingDayEveryOtherForDate(logs, dateStr);

      case HabitFrequency.weekly:
        return _isTrainingDayWeeklyForDate(logs, date, target: 1);

      case HabitFrequency.twiceWeek:
        return _isTrainingDayWeeklyForDate(logs, date, target: 2);

      case HabitFrequency.custom:
        return _isTrainingDayCustomForDate(habit, date);
    }
  }

  // ── Private helpers ───────────────────────────────────

  bool _isTrainingDayEveryOther(List<LogEntry> logs, String today) {
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    // Don't count today's own log (we're checking BEFORE today's action)
    final recentLogs = logs
        .where((l) => l.date != today && l.status != LogStatus.skipped)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (recentLogs.isEmpty) return true; // never executed → training day

    // Training day if no execution yesterday
    return recentLogs.first.date != yesterday;
  }

  /// 判断指定日期是否为 every_other 的训练日。
  /// 逻辑：该日往前看，最近一个非 skip 的打卡日是否为前天（隔一天）。
  bool _isTrainingDayEveryOtherForDate(List<LogEntry> logs, String dateStr) {
    // 不计 skip，按日期降序
    final relevantLogs = logs
        .where((l) => l.date.compareTo(dateStr) < 0 && l.status != LogStatus.skipped)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (relevantLogs.isEmpty) return true; // 从未执行过 → 视为训练日

    final lastDone = relevantLogs.first.date;
    final lastDoneDate = DateTime.parse(lastDone);
    final targetDate = DateTime.parse(dateStr);
    final diff = targetDate.difference(lastDoneDate).inDays;

    // 隔天规则：距离上次完成偶数天 → 训练日
    return diff % 2 == 1;
  }

  bool _isTrainingDayWeekly(List<LogEntry> logs, DateTime now,
      {int target = 1}) {
    // Calculate the start of the current week (Monday)
    final weekday = now.weekday; // 1=Monday, 7=Sunday
    final monday = now.subtract(Duration(days: weekday - 1));
    final weekStart = _dateKey(monday);
    final today = _dateKey(now);

    // Count completions this week (up to yesterday)
    int thisWeekCompleted = 0;
    for (final l in logs) {
      if (l.status == LogStatus.skipped) continue;
      if (l.date.compareTo(weekStart) >= 0 && l.date.compareTo(today) < 0) {
        thisWeekCompleted++;
      }
    }

    return thisWeekCompleted < target;
  }

  /// 判断指定日期所在周是否还需要训练（weekly / twice_week）。
  bool _isTrainingDayWeeklyForDate(List<LogEntry> logs, DateTime date,
      {int target = 1}) {
    final weekday = date.weekday;
    final monday = date.subtract(Duration(days: weekday - 1));
    final weekStart = _dateKey(monday);
    final dateStr = _dateKey(date);

    // 统计该周在指定日期之前（不含当天）的完成次数
    int weekCompleted = 0;
    for (final l in logs) {
      if (l.status == LogStatus.skipped) continue;
      if (l.date.compareTo(weekStart) >= 0 && l.date.compareTo(dateStr) < 0) {
        weekCompleted++;
      }
    }

    return weekCompleted < target;
  }

  // ── Custom days ────────────────────────────────────────

  /// Custom frequency: check if today's weekday is in the custom_days set
  bool _isTrainingDayCustom(Habit habit, DateTime now) {
    final days = habit.customDaysSet;
    if (days.isEmpty) return true; // no days set → treat as daily
    return days.contains(now.weekday);
  }

  bool _isTrainingDayCustomForDate(Habit habit, DateTime date) {
    final days = habit.customDaysSet;
    if (days.isEmpty) return true;
    return days.contains(date.weekday);
  }

  // ── Consecutive miss detection ────────────────────────

  /// Returns true if this habit has been missed on this training day
  /// AND the previous training day (the "never miss twice" rule).
  bool hasConsecutiveMiss(Habit habit, List<LogEntry> logs) {
    final today = _dateKey(DateTime.now());

    // Is today a training day but not yet completed?
    final todayLog = logs.cast<LogEntry?>().firstWhere(
          (l) => l?.date == today,
          orElse: () => null,
        );
    if (todayLog != null) return false; // already done something

    if (!isTrainingDaySync(habit, logs)) return false;

    // Today IS a training day and hasn't been done → look back
    final freq = habit.frequencyEnum;
    if (freq == HabitFrequency.daily) {
      // Daily: check if yesterday was also a miss
      return _wasPreviousTrainingDayMissed(habit, logs, today);
    } else if (freq == HabitFrequency.everyOther) {
      return _wasPreviousTrainingDayMissed(habit, logs, today);
    }

    return false;
  }

  /// Checks whether the most recent training day before today was missed.
  bool _wasPreviousTrainingDayMissed(
      Habit habit, List<LogEntry> logs, String today) {
    // Find the last training day before today
    // For daily: it's always yesterday
    // For every_other: it's 2 days ago
    final previousDay = today == _dateKey(DateTime.now())
        ? _nthPreviousDay(1)
        : _nthPreviousDay(1, from: today);

    final yesterdayLog = logs.cast<LogEntry?>().firstWhere(
          (l) => l?.date == previousDay,
          orElse: () => null,
        );
    if (yesterdayLog == null) return true; // no record = missed

    return yesterdayLog.status == LogStatus.skipped;
  }

  // ── Utility ───────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _nthPreviousDay(int n, {String? from}) {
    DateTime d;
    if (from != null) {
      final parts = from.split('-');
      d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } else {
      d = DateTime.now();
    }
    final target = d.subtract(Duration(days: n));
    return _dateKey(target);
  }
}
