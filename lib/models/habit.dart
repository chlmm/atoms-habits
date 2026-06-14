import 'dart:convert';

enum HabitFrequency {
  daily,
  everyOther,
  weekly,
  twiceWeek,
  custom;

  String get value {
    switch (this) {
      case HabitFrequency.daily:
        return 'daily';
      case HabitFrequency.everyOther:
        return 'every_other';
      case HabitFrequency.weekly:
        return 'weekly';
      case HabitFrequency.twiceWeek:
        return 'twice_week';
      case HabitFrequency.custom:
        return 'custom';
    }
  }

  static HabitFrequency fromString(String s) {
    switch (s) {
      case 'every_other':
        return HabitFrequency.everyOther;
      case 'weekly':
        return HabitFrequency.weekly;
      case 'twice_week':
        return HabitFrequency.twiceWeek;
      case 'custom':
        return HabitFrequency.custom;
      default:
        return HabitFrequency.daily;
    }
  }
}

class Habit {
  final int? id;
  final int milestoneId;
  final String name;
  final String frequency;
  final String? frequencyDesc;
  final String? customDays; // JSON array of weekday numbers (1=Mon,7=Sun), e.g. [1,3,5]
  final String? time; // HH:mm preferred time for this habit
  final String? twoMinVer;
  final bool archived;
  final DateTime created;

  Habit({
    this.id,
    required this.milestoneId,
    required this.name,
    this.frequency = 'daily',
    this.frequencyDesc,
    this.customDays,
    this.time,
    this.twoMinVer,
    this.archived = false,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  HabitFrequency get frequencyEnum => HabitFrequency.fromString(frequency);

  /// Parse customDays into a Set of weekday integers (1=Mon, 7=Sun)
  Set<int> get customDaysSet {
    if (customDays == null || customDays!.isEmpty) return {};
    try {
      final list = jsonDecode(customDays!) as List;
      return list.map((e) => e as int).toSet();
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'milestone_id': milestoneId,
        'name': name,
        'frequency': frequency,
        'frequency_desc': frequencyDesc,
        'custom_days': customDays,
        'time': time,
        'two_min_ver': twoMinVer,
        'archived': archived ? 1 : 0,
        'created': created.toIso8601String(),
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as int?,
        milestoneId: map['milestone_id'] as int,
        name: map['name'] as String,
        frequency: (map['frequency'] as String?) ?? 'daily',
        frequencyDesc: map['frequency_desc'] as String?,
        customDays: map['custom_days'] as String?,
        time: map['time'] as String?,
        twoMinVer: map['two_min_ver'] as String?,
        archived: (map['archived'] as int?) == 1,
        created: DateTime.parse(map['created'] as String),
      );

  Habit copyWith({
    int? id,
    int? milestoneId,
    String? name,
    String? frequency,
    String? frequencyDesc,
    String? customDays,
    String? time,
    String? twoMinVer,
    bool? archived,
    DateTime? created,
  }) =>
      Habit(
        id: id ?? this.id,
        milestoneId: milestoneId ?? this.milestoneId,
        name: name ?? this.name,
        frequency: frequency ?? this.frequency,
        frequencyDesc: frequencyDesc ?? this.frequencyDesc,
        customDays: customDays ?? this.customDays,
        time: time ?? this.time,
        twoMinVer: twoMinVer ?? this.twoMinVer,
        archived: archived ?? this.archived,
        created: created ?? this.created,
      );
}
