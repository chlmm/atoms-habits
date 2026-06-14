enum MilestoneStatus {
  waiting,
  active,
  completed;

  String get value {
    switch (this) {
      case MilestoneStatus.waiting:
        return 'waiting';
      case MilestoneStatus.active:
        return 'active';
      case MilestoneStatus.completed:
        return 'completed';
    }
  }

  static MilestoneStatus fromString(String s) {
    switch (s) {
      case 'active':
        return MilestoneStatus.active;
      case 'completed':
        return MilestoneStatus.completed;
      default:
        return MilestoneStatus.waiting;
    }
  }
}

class Milestone {
  final int? id;
  final int goalId;
  final String name;
  final int sortOrder;
  final String status;
  final String? targetDesc;
  final double? currentValue;
  final double? targetValue;
  final DateTime created;
  final String? completedAt;

  Milestone({
    this.id,
    required this.goalId,
    required this.name,
    this.sortOrder = 0,
    this.status = 'waiting',
    this.targetDesc,
    this.currentValue,
    this.targetValue,
    DateTime? created,
    this.completedAt,
  }) : created = created ?? DateTime.now();

  MilestoneStatus get statusEnum => MilestoneStatus.fromString(status);

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'name': name,
        'sort_order': sortOrder,
        'status': status,
        'target_desc': targetDesc,
        'current_value': currentValue,
        'target_value': targetValue,
        'created': created.toIso8601String(),
        'completed_at': completedAt,
      };

  factory Milestone.fromMap(Map<String, dynamic> map) => Milestone(
        id: map['id'] as int?,
        goalId: map['goal_id'] as int,
        name: map['name'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        status: (map['status'] as String?) ?? 'waiting',
        targetDesc: map['target_desc'] as String?,
        currentValue: (map['current_value'] as num?)?.toDouble(),
        targetValue: (map['target_value'] as num?)?.toDouble(),
        created: DateTime.parse(map['created'] as String),
        completedAt: map['completed_at'] as String?,
      );

  Milestone copyWith({
    int? id,
    int? goalId,
    String? name,
    int? sortOrder,
    String? status,
    String? targetDesc,
    double? currentValue,
    double? targetValue,
    DateTime? created,
    String? completedAt,
  }) =>
      Milestone(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        status: status ?? this.status,
        targetDesc: targetDesc ?? this.targetDesc,
        currentValue: currentValue ?? this.currentValue,
        targetValue: targetValue ?? this.targetValue,
        created: created ?? this.created,
        completedAt: completedAt ?? this.completedAt,
      );
}
