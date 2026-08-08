/// A single feed logged for a cat. Stored at
/// `users/{uid}/cats/{catId}/feedings/{entryId}`.
class FeedingEntry {
  const FeedingEntry({
    required this.id,
    required this.catId,
    required this.foodName,
    required this.foodType,
    required this.amount,
    required this.unit,
    required this.time,
    this.photoUrl,
    this.note,
    this.createdAt,
  });

  final String id;
  final String catId;
  final String foodName;

  /// Free-form: e.g. `dry`, `wet`, `raw`, `treat`, `mixed`.
  final String foodType;
  final double amount;
  final String unit;
  final DateTime time;
  final String? photoUrl;
  final String? note;
  final DateTime? createdAt;

  FeedingEntry copyWith({
    String? id,
    String? catId,
    String? foodName,
    String? foodType,
    double? amount,
    String? unit,
    DateTime? time,
    String? photoUrl,
    String? note,
    DateTime? createdAt,
  }) {
    return FeedingEntry(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      foodName: foodName ?? this.foodName,
      foodType: foodType ?? this.foodType,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      time: time ?? this.time,
      photoUrl: photoUrl ?? this.photoUrl,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'foodName': foodName,
        'foodType': foodType,
        'amount': amount,
        'unit': unit,
        'time': time.toIso8601String(),
        'photoUrl': photoUrl,
        'note': note,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory FeedingEntry.fromJson(Map<String, dynamic> json) {
    return FeedingEntry(
      id: json['id'] as String,
      catId: json['catId'] as String,
      foodName: json['foodName'] as String,
      foodType: json['foodType'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      time: DateTime.parse(json['time'] as String),
      photoUrl: json['photoUrl'] as String?,
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
