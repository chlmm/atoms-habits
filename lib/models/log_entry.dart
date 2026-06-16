enum LogStatus { twoMin, full, skipped, pending }

extension LogStatusExt on LogStatus {
  String get value {
    switch (this) {
      case LogStatus.twoMin:
        return 'two_min';
      case LogStatus.full:
        return 'full';
      case LogStatus.skipped:
        return 'skipped';
      case LogStatus.pending:
        return 'pending';
    }
  }

  static LogStatus fromString(String s) {
    switch (s) {
      case 'full':
        return LogStatus.full;
      case 'skipped':
        return LogStatus.skipped;
      case 'two_min':
        return LogStatus.twoMin;
      default:
        return LogStatus.pending;
    }
  }
}

class LogEntry {
  final int? id;
  final int habitId;
  final String date; // YYYY-MM-DD
  final LogStatus status;
  final String? actionCompletions;
  final String? note;
  final DateTime created;

  LogEntry({
    this.id,
    required this.habitId,
    required this.date,
    required this.status,
    this.actionCompletions,
    this.note,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'habit_id': habitId,
        'date': date,
        'status': status.value,
        'action_completions': actionCompletions,
        'note': note,
        'created': created.toIso8601String(),
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as int?,
        habitId: map['habit_id'] as int,
        date: map['date'] as String,
        status: LogStatusExt.fromString(map['status'] as String),
        actionCompletions: map['action_completions'] as String?,
        note: map['note'] as String?,
        created: DateTime.parse(map['created'] as String),
      );

  LogEntry copyWith({
    int? id,
    int? habitId,
    String? date,
    LogStatus? status,
    String? actionCompletions,
    String? note,
    DateTime? created,
  }) =>
      LogEntry(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        date: date ?? this.date,
        status: status ?? this.status,
        actionCompletions: actionCompletions ?? this.actionCompletions,
        note: note ?? this.note,
        created: created ?? this.created,
      );
}
