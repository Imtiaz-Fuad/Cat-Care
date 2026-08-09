/// A quick observation capturing how the cat is doing today. Stored at
/// `users/{uid}/cats/{catId}/behavior/{logId}`.
///
/// Per PRD §6.11 we capture the snapshot fields plus a free-form note.
/// Booleans are tri-valued via the `*_present` naming: `true` observed,
/// `false` absent, `null` not recorded.
class BehaviorLog {
  const BehaviorLog({
    required this.id,
    required this.catId,
    required this.recordedAt,
    this.appetite,
    this.activity,
    this.mood,
    this.sleepHours,
    this.vomitingPresent,
    this.diarrheaPresent,
    this.urinationNormal,
    this.litterNormal,
    this.aggressionPresent,
    this.hidingPresent,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String catId;
  final DateTime recordedAt;

  /// `1-5` scale (1 = poor, 5 = great). `null` = not recorded.
  final int? appetite;
  final int? activity;
  final int? mood;
  final double? sleepHours;
  final bool? vomitingPresent;
  final bool? diarrheaPresent;
  final bool? urinationNormal;
  final bool? litterNormal;
  final bool? aggressionPresent;
  final bool? hidingPresent;
  final String? notes;
  final DateTime? createdAt;

  BehaviorLog copyWith({
    String? id,
    String? catId,
    DateTime? recordedAt,
    int? appetite,
    int? activity,
    int? mood,
    double? sleepHours,
    bool? vomitingPresent,
    bool? diarrheaPresent,
    bool? urinationNormal,
    bool? litterNormal,
    bool? aggressionPresent,
    bool? hidingPresent,
    String? notes,
    DateTime? createdAt,
  }) {
    return BehaviorLog(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      recordedAt: recordedAt ?? this.recordedAt,
      appetite: appetite ?? this.appetite,
      activity: activity ?? this.activity,
      mood: mood ?? this.mood,
      sleepHours: sleepHours ?? this.sleepHours,
      vomitingPresent: vomitingPresent ?? this.vomitingPresent,
      diarrheaPresent: diarrheaPresent ?? this.diarrheaPresent,
      urinationNormal: urinationNormal ?? this.urinationNormal,
      litterNormal: litterNormal ?? this.litterNormal,
      aggressionPresent: aggressionPresent ?? this.aggressionPresent,
      hidingPresent: hidingPresent ?? this.hidingPresent,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'recordedAt': recordedAt.toIso8601String(),
        'appetite': appetite,
        'activity': activity,
        'mood': mood,
        'sleepHours': sleepHours,
        'vomitingPresent': vomitingPresent,
        'diarrheaPresent': diarrheaPresent,
        'urinationNormal': urinationNormal,
        'litterNormal': litterNormal,
        'aggressionPresent': aggressionPresent,
        'hidingPresent': hidingPresent,
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory BehaviorLog.fromJson(Map<String, dynamic> json) {
    return BehaviorLog(
      id: json['id'] as String,
      catId: json['catId'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      appetite: (json['appetite'] as num?)?.toInt(),
      activity: (json['activity'] as num?)?.toInt(),
      mood: (json['mood'] as num?)?.toInt(),
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      vomitingPresent: json['vomitingPresent'] as bool?,
      diarrheaPresent: json['diarrheaPresent'] as bool?,
      urinationNormal: json['urinationNormal'] as bool?,
      litterNormal: json['litterNormal'] as bool?,
      aggressionPresent: json['aggressionPresent'] as bool?,
      hidingPresent: json['hidingPresent'] as bool?,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
