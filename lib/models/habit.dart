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
  final String? twoMinVer;
  final bool archived;
  final DateTime created;

  Habit({
    this.id,
    required this.milestoneId,
    required this.name,
    this.frequency = 'daily',
    this.frequencyDesc,
    this.twoMinVer,
    this.archived = false,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  HabitFrequency get frequencyEnum => HabitFrequency.fromString(frequency);

  Map<String, dynamic> toMap() => {
        'id': id,
        'milestone_id': milestoneId,
        'name': name,
        'frequency': frequency,
        'frequency_desc': frequencyDesc,
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
        twoMinVer: twoMinVer ?? this.twoMinVer,
        archived: archived ?? this.archived,
        created: created ?? this.created,
      );
}
