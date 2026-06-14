class Review {
  final int? id;
  final int? goalId;
  final String week; // YYYY-Www
  final String? notes;
  final DateTime created;

  Review({
    this.id,
    this.goalId,
    required this.week,
    this.notes,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'week': week,
        'notes': notes,
        'created': created.toIso8601String(),
      };

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'] as int?,
        goalId: map['goal_id'] as int?,
        week: map['week'] as String,
        notes: map['notes'] as String?,
        created: DateTime.parse(map['created'] as String),
      );

  Review copyWith({
    int? id,
    int? goalId,
    String? week,
    String? notes,
    DateTime? created,
  }) =>
      Review(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        week: week ?? this.week,
        notes: notes ?? this.notes,
        created: created ?? this.created,
      );
}
