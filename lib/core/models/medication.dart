/// An active or scheduled medication. Stored at
/// `users/{uid}/cats/{catId}/medications/{medicationId}`.
///
/// `reminderTimes` is the list of local times each day to fire a
/// local notification. `dailyCheckOff` is an explicit acknowledgment that
/// the daily dose was given (separate from the auto reminder).
class Medication {
  const Medication({
    required this.id,
    required this.catId,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.reminderTimes = const <DateTime>[],
    this.dailyCheckOff = const <String, bool>{},
    this.notes,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String catId;
  final String name;
  final String dose;

  /// Free-form frequency string (e.g. `twice_daily`, `every_8_hours`).
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final List<DateTime> reminderTimes;

  /// Map of `YYYY-MM-DD` → `true` when the day was acknowledged.
  final Map<String, bool> dailyCheckOff;
  final String? notes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Medication copyWith({
    String? id,
    String? catId,
    String? name,
    String? dose,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    List<DateTime>? reminderTimes,
    Map<String, bool>? dailyCheckOff,
    String? notes,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      dailyCheckOff: dailyCheckOff ?? this.dailyCheckOff,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'name': name,
        'dose': dose,
        'frequency': frequency,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'reminderTimes':
            reminderTimes.map((DateTime t) => t.toIso8601String()).toList(),
        'dailyCheckOff': dailyCheckOff,
        'notes': notes,
        'active': active,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      catId: json['catId'] as String,
      name: json['name'] as String,
      dose: json['dose'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: _parseDate(json['endDate']),
      reminderTimes: _parseTimeList(json['reminderTimes']),
      dailyCheckOff: _parseCheckOff(json['dailyCheckOff']),
      notes: json['notes'] as String?,
      active: (json['active'] as bool?) ?? true,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  /// True when [day] falls within the medication's [startDate, endDate] range
  /// (end-date inclusive) and the medication is still flagged active.
  bool isActiveOn(DateTime day) {
    if (!active) return false;
    final dayStart = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (dayStart.isBefore(start)) return false;
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dayStart.isAfter(end)) return false;
    }
    return true;
  }

  /// Returns a copy with the check-off flipped for the local day of [day].
  Medication toggleCheckOff(DateTime day) {
    final key = _dayKey(day);
    final next = Map<String, bool>.from(dailyCheckOff);
    next[key] = !(next[key] ?? false);
    return copyWith(dailyCheckOff: next, updatedAt: DateTime.now());
  }

  /// `YYYY-MM-DD` key for [day] in local time.
  String dayKey(DateTime day) => _dayKey(day);

  static String _dayKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<DateTime> _parseTimeList(Object? value) {
  if (value is! List) return const <DateTime>[];
  return value
      .whereType<String>()
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .toList(growable: false);
}

Map<String, bool> _parseCheckOff(Object? value) {
  if (value is! Map) return const <String, bool>{};
  final result = <String, bool>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final v = entry.value;
    if (key is String && v is bool) result[key] = v;
  }
  return result;
}
