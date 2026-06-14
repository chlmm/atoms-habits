import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/action_plan.dart';
import '../models/habit.dart';
import '../models/log_entry.dart';
import '../models/review.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;
  AppDatabase._();

  static const int _currentDbVersion = 3;

  Database? _db;
  Database get db => _db!;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = join(await getDatabasesPath(), 'atoms.db');
    await _handleMigration(dbPath);

    _db = await openDatabase(
      dbPath,
      version: _currentDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
  }

  // ── Migration ────────────────────────────────────────

  Future<void> _handleMigration(String dbPath) async {
    final dbDir = await getDatabasesPath();
    final prefsPath = join(dbDir, 'atoms_prefs.json');
    final prefsFile = File(prefsPath);

    int storedVersion = 0;
    if (await prefsFile.exists()) {
      try {
        final content = await prefsFile.readAsString();
        final prefs = jsonDecode(content) as Map<String, dynamic>;
        storedVersion = prefs['db_version'] as int? ?? 0;
      } catch (_) {
        storedVersion = 0;
      }
    }

    final dbFile = File(dbPath);
    final dbExists = await dbFile.exists();

    if (storedVersion < 1 && dbExists) {
      final backupPath = join(dbDir, 'atoms_v0_backup.db');
      try {
        await dbFile.copy(backupPath);
      } catch (_) {
        // Backup failed, continue with fresh DB
      }
      await dbFile.delete();
    }

    await _writePrefs(prefsFile, {'db_version': _currentDbVersion});
  }

  Future<void> _writePrefs(File file, Map<String, dynamic> prefs) async {
    await file.writeAsString(jsonEncode(prefs));
  }

  // ── Schema ───────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        created TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE milestones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        status TEXT DEFAULT 'waiting',
        target_desc TEXT,
        current_value REAL,
        target_value REAL,
        created TEXT DEFAULT (datetime('now')),
        completed_at TEXT,
        FOREIGN KEY (goal_id) REFERENCES goals(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE action_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (habit_id) REFERENCES habits(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        milestone_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        frequency TEXT DEFAULT 'daily',
        frequency_desc TEXT,
        two_min_ver TEXT,
        archived INTEGER DEFAULT 0,
        created TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (milestone_id) REFERENCES milestones(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        action_completions TEXT,
        note TEXT,
        created TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (habit_id) REFERENCES habits(id),
        UNIQUE(habit_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        week TEXT NOT NULL,
        notes TEXT,
        created TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (goal_id) REFERENCES goals(id),
        UNIQUE(goal_id, week)
      )
    ''');

    await db.execute('''
      CREATE TABLE identity_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        text TEXT NOT NULL,
        accepted INTEGER DEFAULT 0,
        triggered_by TEXT,
        created TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (goal_id) REFERENCES goals(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS identity_insights (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER,
          text TEXT NOT NULL,
          accepted INTEGER DEFAULT 0,
          triggered_by TEXT,
          created TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (goal_id) REFERENCES goals(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      // v3: action_plans 从 milestone 级别改为 habit 级别，删除 habit_actions 中间表
      // 迁移策略：为每个 habit_action 关联创建新的 action_plan(habit_id)，
      // 然后删旧表重建

      // 1. 读取旧 habit_actions 数据
      final oldHabitActions = await db.rawQuery('''
        SELECT ha.habit_id, ap.name, ha.sort_order
        FROM habit_actions ha
        INNER JOIN action_plans ap ON ap.id = ha.action_plan_id
      ''');

      // 2. 删旧 action_plans 和 habit_actions
      await db.execute('DROP TABLE IF EXISTS habit_actions');
      await db.execute('DROP TABLE IF EXISTS action_plans');

      // 3. 创建新 action_plans (habit_id)
      await db.execute('''
        CREATE TABLE action_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          created TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (habit_id) REFERENCES habits(id)
        )
      ''');

      // 4. 插入迁移数据
      for (final row in oldHabitActions) {
        await db.insert('action_plans', {
          'habit_id': row['habit_id'],
          'name': row['name'],
          'sort_order': row['sort_order'] ?? 0,
          'created': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  // ── Goals ────────────────────────────────────────────

  Future<int> insertGoal(Goal goal) =>
      db.insert('goals', goal.toMap()..remove('id'));

  Future<int> updateGoal(Goal goal) =>
      db.update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);

  Future<int> deleteGoal(int id) =>
      db.delete('goals', where: 'id = ?', whereArgs: [id]);

  Future<List<Goal>> getAllGoals() async {
    final rows = await db.query('goals', orderBy: 'created DESC');
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal?> getGoal(int id) async {
    final rows = await db.query('goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  Future<List<Goal>> getActiveGoals() async {
    final rows = await db.query('goals',
        where: "status = 'active'", orderBy: 'created DESC');
    return rows.map(Goal.fromMap).toList();
  }

  // ── Milestones ───────────────────────────────────────

  Future<int> insertMilestone(Milestone m) =>
      db.insert('milestones', m.toMap()..remove('id'));

  Future<int> updateMilestone(Milestone m) =>
      db.update('milestones', m.toMap(), where: 'id = ?', whereArgs: [m.id]);

  Future<int> deleteMilestone(int id) =>
      db.delete('milestones', where: 'id = ?', whereArgs: [id]);

  Future<List<Milestone>> getMilestonesByGoal(int goalId) async {
    final rows = await db.query('milestones',
        where: 'goal_id = ?', whereArgs: [goalId], orderBy: 'sort_order ASC');
    return rows.map(Milestone.fromMap).toList();
  }

  Future<Milestone?> getMilestone(int id) async {
    final rows =
        await db.query('milestones', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Milestone.fromMap(rows.first);
  }

  Future<Milestone?> getActiveMilestone(int goalId) async {
    final rows = await db.query('milestones',
        where: "goal_id = ? AND status = 'active'",
        whereArgs: [goalId],
        limit: 1);
    if (rows.isEmpty) return null;
    return Milestone.fromMap(rows.first);
  }

  Future<int> getMilestoneCount(int goalId) async {
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM milestones WHERE goal_id = ?', [goalId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Action Plans (habit-level) ──────────────────────

  Future<int> insertActionPlan(ActionPlan ap) =>
      db.insert('action_plans', ap.toMap()..remove('id'));

  Future<int> updateActionPlan(ActionPlan ap) =>
      db.update('action_plans', ap.toMap(), where: 'id = ?', whereArgs: [ap.id]);

  Future<int> deleteActionPlan(int id) =>
      db.delete('action_plans', where: 'id = ?', whereArgs: [id]);

  Future<List<ActionPlan>> getActionPlansForHabit(int habitId) async {
    final rows = await db.query('action_plans',
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'sort_order ASC');
    return rows.map(ActionPlan.fromMap).toList();
  }

  Future<int> deleteActionPlansForHabit(int habitId) =>
      db.delete('action_plans', where: 'habit_id = ?', whereArgs: [habitId]);

  // ── Habits ───────────────────────────────────────────

  Future<int> insertHabit(Habit h) =>
      db.insert('habits', h.toMap()..remove('id'));

  Future<int> updateHabit(Habit h) =>
      db.update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);

  Future<int> deleteHabit(int id) =>
      db.delete('habits', where: 'id = ?', whereArgs: [id]);

  Future<int> archiveHabit(int id) =>
      db.update('habits', {'archived': 1}, where: 'id = ?', whereArgs: [id]);

  Future<List<Habit>> getHabitsByMilestone(int milestoneId,
      {bool includeArchived = false}) async {
    var where = 'milestone_id = ?';
    var whereArgs = [milestoneId];
    if (!includeArchived) {
      where += ' AND archived = 0';
    }
    final rows = await db.query('habits',
        where: where, whereArgs: whereArgs, orderBy: 'created ASC');
    return rows.map(Habit.fromMap).toList();
  }

  Future<Habit?> getHabit(int id) async {
    final rows = await db.query('habits', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first);
  }

  Future<List<Habit>> getAllHabits({bool includeArchived = false}) async {
    var where = includeArchived ? null : 'archived = 0';
    final rows = await db.query('habits', where: where, orderBy: 'created ASC');
    return rows.map(Habit.fromMap).toList();
  }

  // ── Logs ─────────────────────────────────────────────

  Future<int> insertLog(LogEntry log) =>
      db.insert('logs', log.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> updateLog(LogEntry log) =>
      db.update('logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);

  Future<LogEntry?> getLogForDate(int habitId, String date) async {
    final rows = await db.query('logs',
        where: 'habit_id = ? AND date = ?', whereArgs: [habitId, date]);
    if (rows.isEmpty) return null;
    return LogEntry.fromMap(rows.first);
  }

  Future<List<LogEntry>> getLogsForHabit(int habitId,
      {int limit = 365}) async {
    final rows = await db.query('logs',
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'date DESC',
        limit: limit);
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<int> getTotalCompletedCount(int habitId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM logs WHERE habit_id = ? AND status != ?',
      [habitId, 'skipped'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, String>> getRecentStatuses(int habitId, int days) async {
    final rows = await db.query('logs',
        columns: ['date', 'status'],
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'date DESC',
        limit: days);
    final statuses = <String, String>{};
    for (final row in rows) {
      statuses[row['date'] as String] = row['status'] as String;
    }
    return statuses;
  }

  /// Aggregate check-in counts per day across ALL active habits.
  /// Returns Map<dateString, count> e.g. {'2025-06-14': 3}
  Future<Map<String, int>> getDailyCheckinCounts({
    required String startDate,
    required String endDate,
  }) async {
    final rows = await db.rawQuery('''
      SELECT l.date, COUNT(*) as cnt
      FROM logs l
      INNER JOIN habits h ON h.id = l.habit_id
      WHERE l.date >= ? AND l.date <= ?
        AND h.archived = 0
        AND l.status != 'skipped'
      GROUP BY l.date
      ORDER BY l.date ASC
    ''', [startDate, endDate]);

    final map = <String, int>{};
    for (final row in rows) {
      map[row['date'] as String] = row['cnt'] as int;
    }
    return map;
  }

  /// 获取某天所有活跃习惯的打卡状态。
  /// 返回 List<Map>，每个 map 包含 habit_id, name, frequency, status(可null)。
  Future<List<Map<String, dynamic>>> getHabitsWithStatusForDate(String date) async {
    return db.rawQuery('''
      SELECT h.id AS habit_id, h.name, h.frequency,
             l.status AS log_status, l.note AS log_note
      FROM habits h
      LEFT JOIN logs l ON l.habit_id = h.id AND l.date = ?
      WHERE h.archived = 0
      ORDER BY h.created ASC
    ''', [date]);
  }

  /// Count of distinct days with at least one check-in.
  Future<int> getActiveDaysCount({
    required String startDate,
    required String endDate,
  }) async {
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT l.date) as cnt
      FROM logs l
      INNER JOIN habits h ON h.id = l.habit_id
      WHERE l.date >= ? AND l.date <= ?
        AND h.archived = 0
        AND l.status != 'skipped'
    ''', [startDate, endDate]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Reviews ──────────────────────────────────────────

  Future<int> insertReview(Review review) =>
      db.insert('reviews', review.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> updateReview(Review review) =>
      db.update('reviews', review.toMap(),
          where: 'id = ?', whereArgs: [review.id]);

  Future<Review?> getReviewForWeek(String week, {int? goalId}) async {
    final rows = await db.query('reviews',
        where: 'week = ? AND goal_id IS ?',
        whereArgs: [week, goalId]);
    if (rows.isEmpty) return null;
    return Review.fromMap(rows.first);
  }

  Future<List<Review>> getAllReviews({int? goalId}) async {
    String? where;
    List<dynamic>? whereArgs;
    if (goalId != null) {
      where = 'goal_id = ?';
      whereArgs = [goalId];
    }
    final rows = await db.query('reviews',
        where: where, whereArgs: whereArgs, orderBy: 'week DESC');
    return rows.map(Review.fromMap).toList();
  }

  Future<int> deleteReview(int id) =>
      db.delete('reviews', where: 'id = ?', whereArgs: [id]);

  // ── CLI Diagnostics ──────────────────────────────────

  Future<Map<String, int>> getTableStats() async {
    final tables = [
      'goals',
      'milestones',
      'habits',
      'action_plans',
      'logs',
      'reviews',
      'identity_insights'
    ];
    final stats = <String, int>{};
    for (final table in tables) {
      final result = await db
          .rawQuery('SELECT COUNT(*) as cnt FROM $table');
      stats[table] = Sqflite.firstIntValue(result) ?? 0;
    }
    return stats;
  }

  Future<void> resetAllData() async {
    // Delete in reverse FK order
    await db.delete('identity_insights');
    await db.delete('logs');
    await db.delete('reviews');
    await db.delete('action_plans');
    await db.delete('habits');
    await db.delete('milestones');
    await db.delete('goals');
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    return db.transaction((txn) => action());
  }

  // ── Utility ──────────────────────────────────────────

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}';
  }

  // ── Identity Insights ────────────────────────────────

  Future<int> insertIdentityInsight(dynamic insight) =>
      db.insert('identity_insights', (insight as dynamic).toMap()..remove('id'));

  Future<void> updateIdentityInsight(dynamic insight) =>
      db.update('identity_insights', (insight as dynamic).toMap(),
          where: 'id = ?', whereArgs: [(insight as dynamic).id]);

  Future<dynamic> getIdentityInsight(int id) async {
    final rows = await db
        .query('identity_insights', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<dynamic>> getIdentityInsights({int? goalId}) async {
    String? where;
    List<dynamic>? whereArgs;
    if (goalId != null) {
      where = 'goal_id = ?';
      whereArgs = [goalId];
    }
    final rows = await db.query('identity_insights',
        where: where, whereArgs: whereArgs, orderBy: 'created DESC');
    return rows;
  }

  Future<List<dynamic>> getIdentityInsightsForHabit(int habitId) async {
    final rows = await db.query('identity_insights',
        where: "triggered_by LIKE ?",
        whereArgs: ['%habit_id=$habitId%'],
        orderBy: 'created DESC');
    return rows;
  }
}
