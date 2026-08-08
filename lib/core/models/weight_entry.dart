/// A single weight measurement. Stored at
/// `users/{uid}/cats/{catId}/weights/{entryId}`.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.catId,
    required this.weightKg,
    required this.recordedAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String catId;
  final double weightKg;
  final DateTime recordedAt;
  final String? notes;
  final DateTime? createdAt;

  WeightEntry copyWith({
    String? id,
    String? catId,
    double? weightKg,
    DateTime? recordedAt,
    String? notes,
    DateTime? createdAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      weightKg: weightKg ?? this.weightKg,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'weightKg': weightKg,
        'recordedAt': recordedAt.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String,
      catId: json['catId'] as String,
      weightKg: (json['weightKg'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
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
