/// A single food item from the content layer. Stored at
/// `content/food/{id}`.
///
/// Per PRD §10, every fact here must be supplied by the product owner.
/// `missingData == true` means the entry is still a placeholder and the UI
/// must render a `[CONTENT PLACEHOLDER]` banner. UI must NEVER invent
/// nutritional values.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.foodType,
    this.brand,
    this.description,
    this.suitableLifeStages = const <String>[],
    this.typicalServingGrams,
    this.caloriesPerServing,
    this.proteinPercent,
    this.fatPercent,
    this.fiberPercent,
    this.moisturePercent,
    this.notes,
    this.source,
    this.missingData = true,
  });

  final String id;
  final String name;

  /// Free-form: `dry`, `wet`, `raw`, `treat`, `human_food`.
  final String foodType;
  final String? brand;
  final String? description;
  final List<String> suitableLifeStages;
  final double? typicalServingGrams;
  final double? caloriesPerServing;
  final double? proteinPercent;
  final double? fatPercent;
  final double? fiberPercent;
  final double? moisturePercent;
  final String? notes;
  final String? source;
  final bool missingData;

  FoodItem copyWith({
    String? id,
    String? name,
    String? foodType,
    String? brand,
    String? description,
    List<String>? suitableLifeStages,
    double? typicalServingGrams,
    double? caloriesPerServing,
    double? proteinPercent,
    double? fatPercent,
    double? fiberPercent,
    double? moisturePercent,
    String? notes,
    String? source,
    bool? missingData,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      foodType: foodType ?? this.foodType,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      suitableLifeStages: suitableLifeStages ?? this.suitableLifeStages,
      typicalServingGrams: typicalServingGrams ?? this.typicalServingGrams,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      fiberPercent: fiberPercent ?? this.fiberPercent,
      moisturePercent: moisturePercent ?? this.moisturePercent,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'foodType': foodType,
        'brand': brand,
        'description': description,
        'suitableLifeStages': suitableLifeStages,
        'typicalServingGrams': typicalServingGrams,
        'caloriesPerServing': caloriesPerServing,
        'proteinPercent': proteinPercent,
        'fatPercent': fatPercent,
        'fiberPercent': fiberPercent,
        'moisturePercent': moisturePercent,
        'notes': notes,
        'source': source,
        'missingData': missingData,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      foodType: json['foodType'] as String,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      suitableLifeStages: _stringList(json['suitableLifeStages']),
      typicalServingGrams: (json['typicalServingGrams'] as num?)?.toDouble(),
      caloriesPerServing: (json['caloriesPerServing'] as num?)?.toDouble(),
      proteinPercent: (json['proteinPercent'] as num?)?.toDouble(),
      fatPercent: (json['fatPercent'] as num?)?.toDouble(),
      fiberPercent: (json['fiberPercent'] as num?)?.toDouble(),
      moisturePercent: (json['moisturePercent'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
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
