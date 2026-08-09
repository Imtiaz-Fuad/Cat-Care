/// A kitten developmental milestone. Stored at
/// `content/kitten_milestone/{id}`.
///
/// `expectedAgeWeeks` is the typical age at which the milestone happens.
class KittenMilestone {
  const KittenMilestone({
    required this.id,
    required this.title,
    required this.expectedAgeWeeks,
    this.description,
    this.tips = const <String>[],
    this.source,
    this.missingData = true,
  });

  final String id;
  final String title;
  final int expectedAgeWeeks;
  final String? description;
  final List<String> tips;
  final String? source;
  final bool missingData;

  KittenMilestone copyWith({
    String? id,
    String? title,
    int? expectedAgeWeeks,
    String? description,
    List<String>? tips,
    String? source,
    bool? missingData,
  }) {
    return KittenMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      expectedAgeWeeks: expectedAgeWeeks ?? this.expectedAgeWeeks,
      description: description ?? this.description,
      tips: tips ?? this.tips,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'expectedAgeWeeks': expectedAgeWeeks,
        'description': description,
        'tips': tips,
        'source': source,
        'missingData': missingData,
      };

  factory KittenMilestone.fromJson(Map<String, dynamic> json) {
    return KittenMilestone(
      id: json['id'] as String,
      title: json['title'] as String,
      expectedAgeWeeks: (json['expectedAgeWeeks'] as num).toInt(),
      description: json['description'] as String?,
      tips: _stringList(json['tips']),
      source: json['source'] as String?,
      missingData: (json['missingData'] as bool?) ?? true,
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}
