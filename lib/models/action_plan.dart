class ActionPlan {
  final int? id;
  final int habitId;
  final String name;
  final int sortOrder;
  final DateTime created;

  ActionPlan({
    this.id,
    required this.habitId,
    required this.name,
    this.sortOrder = 0,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'habit_id': habitId,
        'name': name,
        'sort_order': sortOrder,
        'created': created.toIso8601String(),
      };

  factory ActionPlan.fromMap(Map<String, dynamic> map) => ActionPlan(
        id: map['id'] as int?,
        habitId: map['habit_id'] as int,
        name: map['name'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        created: DateTime.parse(map['created'] as String),
      );

  ActionPlan copyWith({
    int? id,
    int? habitId,
    String? name,
    int? sortOrder,
    DateTime? created,
  }) =>
      ActionPlan(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        created: created ?? this.created,
      );
}
