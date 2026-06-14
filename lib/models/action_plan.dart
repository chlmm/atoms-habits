class ActionPlan {
  final int? id;
  final int milestoneId;
  final String name;
  final int sortOrder;
  final DateTime created;

  ActionPlan({
    this.id,
    required this.milestoneId,
    required this.name,
    this.sortOrder = 0,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'milestone_id': milestoneId,
        'name': name,
        'sort_order': sortOrder,
        'created': created.toIso8601String(),
      };

  factory ActionPlan.fromMap(Map<String, dynamic> map) => ActionPlan(
        id: map['id'] as int?,
        milestoneId: map['milestone_id'] as int,
        name: map['name'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        created: DateTime.parse(map['created'] as String),
      );

  ActionPlan copyWith({
    int? id,
    int? milestoneId,
    String? name,
    int? sortOrder,
    DateTime? created,
  }) =>
      ActionPlan(
        id: id ?? this.id,
        milestoneId: milestoneId ?? this.milestoneId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        created: created ?? this.created,
      );
}
