import '../modules/database.dart';
import '../models/identity_insight.dart';

class IdentityService {
  final AppDatabase _db;

  IdentityService(this._db);

  Future<IdentityInsight> createInsight(IdentityInsight insight) async {
    final id = await _db.insertIdentityInsight(insight);
    return insight.copyWith(id: id);
  }

  Future<List<IdentityInsight>> getInsights({int? goalId}) async {
    final rows = await _db.getIdentityInsights(goalId: goalId);
    return rows.map((r) => IdentityInsight.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<IdentityInsight?> getInsight(int id) async {
    final row = await _db.getIdentityInsight(id);
    if (row == null) return null;
    return IdentityInsight.fromMap(row as Map<String, dynamic>);
  }

  Future<IdentityInsight> acceptInsight(int id) async {
    final insight = await getInsight(id);
    if (insight == null) throw Exception('insight not found');
    final updated = insight.copyWith(accepted: true);
    await _db.updateIdentityInsight(updated);
    return updated;
  }

  Future<IdentityInsight> updateInsightText(int id, String text) async {
    final insight = await getInsight(id);
    if (insight == null) throw Exception('insight not found');
    final updated = insight.copyWith(text: text);
    await _db.updateIdentityInsight(updated);
    return updated;
  }

  /// Check if any habit qualifies for identity insight generation.
  /// Trigger: habit completed >= 15 times AND first log >= 21 days ago.
  Future<List<Map<String, dynamic>>> checkTriggers() async {
    final habits = await _db.getAllHabits(includeArchived: false);
    final triggered = <Map<String, dynamic>>[];

    for (final h in habits) {
      if (h.id == null) continue;
      final total = await _db.getTotalCompletedCount(h.id!);
      if (total < 15) continue;

      // Get the earliest log to check if >= 21 days since first completion
      final logs = await _db.getLogsForHabit(h.id!, limit: 365);
      if (logs.isEmpty) continue;
      final firstLog = logs.last; // getLogsForHabit returns DESC, so last = earliest
      final firstDate = DateTime.parse(firstLog.date);
      final daysSince = DateTime.now().difference(firstDate).inDays;
      if (daysSince < 21) continue;

      // Check if already has accepted insight for this habit
      final existing = await _db.getIdentityInsightsForHabit(h.id!);
      if (existing.any((i) => (i as Map<String, dynamic>)['accepted'] == 1)) continue;

      triggered.add({
        'habit_id': h.id,
        'habit_name': h.name,
        'total_completed': total,
        'days_since_first': daysSince,
      });
    }

    return triggered;
  }

  /// Generate identity text from habit data.
  String generateIdentityText(String habitName, String goalName) {
    final keywords = <String, String>{
      '练背': '爱运动的人',
      '核心': '爱运动的人',
      '跑步': '跑步者',
      '阅读': '爱阅读的人',
      '读书': '爱阅读的人',
      '写作': '爱写作的人',
      '冥想': '内心平静的人',
      '游泳': '游泳者',
      '健身': '爱运动的人',
    };

    for (final entry in keywords.entries) {
      if (habitName.contains(entry.key) || goalName.contains(entry.key)) {
        return entry.value;
      }
    }

    return '坚持不懈的人';
  }
}
