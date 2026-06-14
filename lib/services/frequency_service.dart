import '../models/habit.dart';
import '../models/log_entry.dart';

/// Frequency engine that determines which habits should appear
/// as training/reviewable on a given date.
///
/// Pure logic — no DB access. Takes habit + log history as input.
class FrequencyService {
  /// Returns the target number of executions per week for a given frequency.
  static int weeklyTarget(String frequency) {
    switch (frequency) {
      case 'daily':
        return 7;
      case 'every_other':
        return 4; // ~3.5, rounded up
      case 'weekly':
        return 1;
      case 'twice_week':
        return 2;
      case 'custom':
        return 1; // conservative default
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

    // If already completed today (full or two_min), still show it
    // (it will display as "已完成" but we don't hide it)
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
        // v1 simplification: treat as daily
        return true;
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
