/// A schedule entry consumed by the local-notification layer (cross-platform
/// via `flutter_local_notifications`). Maps a Firebase document to a local
/// notification id by recording both the source entity and the resulting
/// notification id.
class NotificationSchedule {
  const NotificationSchedule({
    required this.id,
    required this.catId,
    required this.channelKey,
    required this.title,
    required this.body,
    required this.fireAt,
    this.payload,
    this.sourceType,
    this.sourceId,
    this.createdAt,
  });

  final String id;
  final String catId;
  final String channelKey;
  final String title;
  final String body;
  final DateTime fireAt;
  final String? payload;

  /// e.g. `routine`, `vaccination`, `medication`, `deworming`.
  final String? sourceType;
  final String? sourceId;
  final DateTime? createdAt;

  NotificationSchedule copyWith({
    String? id,
    String? catId,
    String? channelKey,
    String? title,
    String? body,
    DateTime? fireAt,
    String? payload,
    String? sourceType,
    String? sourceId,
    DateTime? createdAt,
  }) {
    return NotificationSchedule(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      channelKey: channelKey ?? this.channelKey,
      title: title ?? this.title,
      body: body ?? this.body,
      fireAt: fireAt ?? this.fireAt,
      payload: payload ?? this.payload,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'channelKey': channelKey,
        'title': title,
        'body': body,
        'fireAt': fireAt.toIso8601String(),
        'payload': payload,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory NotificationSchedule.fromJson(Map<String, dynamic> json) {
    return NotificationSchedule(
      id: json['id'] as String,
      catId: json['catId'] as String,
      channelKey: json['channelKey'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      fireAt: DateTime.parse(json['fireAt'] as String),
      payload: json['payload'] as String?,
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
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
