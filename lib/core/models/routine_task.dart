/// A user-defined care task. Stored at
/// `users/{uid}/cats/{catId}/routines/{taskId}`.
class RoutineTask {
  const RoutineTask({
    required this.id,
    required this.catId,
    required this.title,
    required this.category,
    this.timeOfDay,
    this.repeat = 'daily',
    this.reminder = false,
    this.notes,
    this.completed = false,
    this.lastCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String catId;
  final String title;
  final String category;

  /// Local wall-clock time of day. `null` means "no specific time".
  final DateTime? timeOfDay;

  /// One of: `daily`, `weekly`, `monthly`, `custom`.
  final String repeat;
  final bool reminder;
  final String? notes;
  final bool completed;
  final DateTime? lastCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RoutineTask copyWith({
    String? id,
    String? catId,
    String? title,
    String? category,
    DateTime? timeOfDay,
    String? repeat,
    bool? reminder,
    String? notes,
    bool? completed,
    DateTime? lastCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoutineTask(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      title: title ?? this.title,
      category: category ?? this.category,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      repeat: repeat ?? this.repeat,
      reminder: reminder ?? this.reminder,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'title': title,
        'category': category,
        'timeOfDay': timeOfDay?.toIso8601String(),
        'repeat': repeat,
        'reminder': reminder,
        'notes': notes,
        'completed': completed,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory RoutineTask.fromJson(Map<String, dynamic> json) {
    return RoutineTask(
      id: json['id'] as String,
      catId: json['catId'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      timeOfDay: _parseDate(json['timeOfDay']),
      repeat: (json['repeat'] as String?) ?? 'daily',
      reminder: (json['reminder'] as bool?) ?? false,
      notes: json['notes'] as String?,
      completed: (json['completed'] as bool?) ?? false,
      lastCompletedAt: _parseDate(json['lastCompletedAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
