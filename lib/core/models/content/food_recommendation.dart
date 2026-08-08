/// A recommendation describing how to feed a cat of a given life stage.
/// Stored at `content/food_recommendation/{id}` keyed by life-stage +
/// activity level.
class FoodRecommendation {
  const FoodRecommendation({
    required this.id,
    required this.lifeStage,
    required this.activityLevel,
    this.mealsPerDay,
    this.gramsPerDay,
    this.waterMlPerDay,
    this.notes,
    this.source,
    this.missingData = true,
  });

  final String id;

  /// `kitten`, `junior`, `adult`, `mature`, or `senior`.
  final String lifeStage;

  /// `low`, `moderate`, `high`.
  final String activityLevel;
  final int? mealsPerDay;
  final double? gramsPerDay;
  final double? waterMlPerDay;
  final String? notes;
  final String? source;
  final bool missingData;

  FoodRecommendation copyWith({
    String? id,
    String? lifeStage,
    String? activityLevel,
    int? mealsPerDay,
    double? gramsPerDay,
    double? waterMlPerDay,
    String? notes,
    String? source,
    bool? missingData,
  }) {
    return FoodRecommendation(
      id: id ?? this.id,
      lifeStage: lifeStage ?? this.lifeStage,
      activityLevel: activityLevel ?? this.activityLevel,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      gramsPerDay: gramsPerDay ?? this.gramsPerDay,
      waterMlPerDay: waterMlPerDay ?? this.waterMlPerDay,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'lifeStage': lifeStage,
        'activityLevel': activityLevel,
        'mealsPerDay': mealsPerDay,
        'gramsPerDay': gramsPerDay,
        'waterMlPerDay': waterMlPerDay,
        'notes': notes,
        'source': source,
        'missingData': missingData,
      };

  factory FoodRecommendation.fromJson(Map<String, dynamic> json) {
    return FoodRecommendation(
      id: json['id'] as String,
      lifeStage: json['lifeStage'] as String,
      activityLevel: json['activityLevel'] as String,
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt(),
      gramsPerDay: (json['gramsPerDay'] as num?)?.toDouble(),
      waterMlPerDay: (json['waterMlPerDay'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      source: json['source'] as String?,
      missingData: (json['missingData'] as bool?) ?? true,
    );
  }
}
