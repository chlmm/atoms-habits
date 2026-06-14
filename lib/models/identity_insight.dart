class IdentityInsight {
  final int? id;
  final int? goalId;
  final String text;
  final bool accepted;
  final String? triggeredBy;
  final DateTime created;

  IdentityInsight({
    this.id,
    this.goalId,
    required this.text,
    this.accepted = false,
    this.triggeredBy,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'text': text,
        'accepted': accepted ? 1 : 0,
        'triggered_by': triggeredBy,
        'created': created.toIso8601String(),
      };

  factory IdentityInsight.fromMap(Map<String, dynamic> map) =>
      IdentityInsight(
        id: map['id'] as int?,
        goalId: map['goal_id'] as int?,
        text: map['text'] as String,
        accepted: (map['accepted'] as int?) == 1,
        triggeredBy: map['triggered_by'] as String?,
        created: map['created'] != null
            ? DateTime.parse(map['created'] as String)
            : null,
      );

  IdentityInsight copyWith({
    int? id,
    int? goalId,
    String? text,
    bool? accepted,
    String? triggeredBy,
    DateTime? created,
  }) =>
      IdentityInsight(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        text: text ?? this.text,
        accepted: accepted ?? this.accepted,
        triggeredBy: triggeredBy ?? this.triggeredBy,
        created: created ?? this.created,
      );
}
