/// A single water-intake log entry. Stored at
/// `users/{uid}/cats/{catId}/water/{entryId}`.
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.catId,
    required this.amountMl,
    required this.time,
    this.note,
    this.createdAt,
  });

  final String id;
  final String catId;
  final double amountMl;
  final DateTime time;
  final String? note;
  final DateTime? createdAt;

  WaterEntry copyWith({
    String? id,
    String? catId,
    double? amountMl,
    DateTime? time,
    String? note,
    DateTime? createdAt,
  }) {
    return WaterEntry(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      amountMl: amountMl ?? this.amountMl,
      time: time ?? this.time,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'amountMl': amountMl,
        'time': time.toIso8601String(),
        'note': note,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    return WaterEntry(
      id: json['id'] as String,
      catId: json['catId'] as String,
      amountMl: (json['amountMl'] as num).toDouble(),
      time: DateTime.parse(json['time'] as String),
      note: json['note'] as String?,
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
