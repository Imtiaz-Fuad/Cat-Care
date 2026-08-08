/// Breed profile reference. Stored at `content/breed/{id}`.
///
/// `typicalWeightKg` is `[min, max]`. `groomingNeeds` is one of `low`,
/// `medium`, `high`. `activityLevel` is `low`, `moderate`, `high`.
class BreedInfo {
  const BreedInfo({
    required this.id,
    required this.name,
    required this.typicalWeightKg,
    required this.activityLevel,
    required this.groomingNeeds,
    this.description,
    this.commonHealthIssues = const <String>[],
    this.notes,
    this.source,
    this.missingData = true,
  });

  final String id;
  final String name;
  final List<double> typicalWeightKg;
  final String activityLevel;
  final String groomingNeeds;
  final String? description;
  final List<String> commonHealthIssues;
  final String? notes;
  final String? source;
  final bool missingData;

  BreedInfo copyWith({
    String? id,
    String? name,
    List<double>? typicalWeightKg,
    String? activityLevel,
    String? groomingNeeds,
    String? description,
    List<String>? commonHealthIssues,
    String? notes,
    String? source,
    bool? missingData,
  }) {
    return BreedInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      typicalWeightKg: typicalWeightKg ?? this.typicalWeightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      groomingNeeds: groomingNeeds ?? this.groomingNeeds,
      description: description ?? this.description,
      commonHealthIssues: commonHealthIssues ?? this.commonHealthIssues,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'typicalWeightKg': typicalWeightKg,
        'activityLevel': activityLevel,
        'groomingNeeds': groomingNeeds,
        'description': description,
        'commonHealthIssues': commonHealthIssues,
        'notes': notes,
        'source': source,
        'missingData': missingData,
      };

  factory BreedInfo.fromJson(Map<String, dynamic> json) {
    return BreedInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      typicalWeightKg: _doubleList(json['typicalWeightKg']),
      activityLevel: (json['activityLevel'] as String?) ?? 'moderate',
      groomingNeeds: (json['groomingNeeds'] as String?) ?? 'medium',
      description: json['description'] as String?,
      commonHealthIssues: _stringList(json['commonHealthIssues']),
      notes: json['notes'] as String?,
      source: json['source'] as String?,
      missingData: (json['missingData'] as bool?) ?? true,
    );
  }
}

List<double> _doubleList(Object? value) {
  if (value is List) {
    return value
        .whereType<num>()
        .map((num n) => n.toDouble())
        .toList(growable: false);
  }
  return const <double>[];
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}
