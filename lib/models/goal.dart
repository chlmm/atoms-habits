enum GoalStatus {
  active,
  completed,
  archived;

  String get value {
    switch (this) {
      case GoalStatus.active:
        return 'active';
      case GoalStatus.completed:
        return 'completed';
      case GoalStatus.archived:
        return 'archived';
    }
  }

  static GoalStatus fromString(String s) {
    switch (s) {
      case 'completed':
        return GoalStatus.completed;
      case 'archived':
        return GoalStatus.archived;
      default:
        return GoalStatus.active;
    }
  }
}

class Goal {
  final int? id;
  final String name;
  final String status;
  final DateTime created;

  Goal({
    this.id,
    required this.name,
    this.status = 'active',
    DateTime? created,
  }) : created = created ?? DateTime.now();

  GoalStatus get statusEnum => GoalStatus.fromString(status);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'status': status,
        'created': created.toIso8601String(),
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as int?,
        name: map['name'] as String,
        status: (map['status'] as String?) ?? 'active',
        created: DateTime.parse(map['created'] as String),
      );

  Goal copyWith({
    int? id,
    String? name,
    String? status,
    DateTime? created,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
        created: created ?? this.created,
      );
}
