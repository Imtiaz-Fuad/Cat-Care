import 'cat_life_stage.dart';

/// The owner's record of a cat. Stored at `users/{uid}/cats/{catId}`.
///
/// `id`, `ownerId`, and `themeAccentHex` are required so the UI can route
/// to a profile and tint accents (per design §6). All other fields are
/// optional but most are populated during onboarding.
class CatProfile {
  const CatProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    this.birthday,
    this.sex,
    this.breed,
    this.neutered = false,
    this.indoor = true,
    this.color,
    this.weightKg,
    this.allergies = const <String>[],
    this.diseases = const <String>[],
    this.medications = const <String>[],
    this.notes,
    this.photoUrl,
    this.themeAccentHex,
    this.priorities = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final DateTime? birthday;
  final String? sex;
  final String? breed;
  final bool neutered;
  final bool indoor;
  final String? color;
  final double? weightKg;
  final List<String> allergies;
  final List<String> diseases;
  final List<String> medications;
  final String? notes;
  final String? photoUrl;
  final String? themeAccentHex;
  final List<String> priorities;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Life-stage derived from [birthday]. `adult` when unknown.
  CatLifeStage get lifeStage => CatLifeStage.fromBirthday(birthday);

  CatProfile copyWith({
    String? id,
    String? ownerId,
    String? name,
    DateTime? birthday,
    String? sex,
    String? breed,
    bool? neutered,
    bool? indoor,
    String? color,
    double? weightKg,
    List<String>? allergies,
    List<String>? diseases,
    List<String>? medications,
    String? notes,
    String? photoUrl,
    String? themeAccentHex,
    List<String>? priorities,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      sex: sex ?? this.sex,
      breed: breed ?? this.breed,
      neutered: neutered ?? this.neutered,
      indoor: indoor ?? this.indoor,
      color: color ?? this.color,
      weightKg: weightKg ?? this.weightKg,
      allergies: allergies ?? this.allergies,
      diseases: diseases ?? this.diseases,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      themeAccentHex: themeAccentHex ?? this.themeAccentHex,
      priorities: priorities ?? this.priorities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'birthday': birthday?.toIso8601String(),
        'sex': sex,
        'breed': breed,
        'neutered': neutered,
        'indoor': indoor,
        'color': color,
        'weightKg': weightKg,
        'allergies': allergies,
        'diseases': diseases,
        'medications': medications,
        'notes': notes,
        'photoUrl': photoUrl,
        'themeAccentHex': themeAccentHex,
        'priorities': priorities,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CatProfile.fromJson(Map<String, dynamic> json) {
    return CatProfile(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      birthday: _parseDate(json['birthday']),
      sex: json['sex'] as String?,
      breed: json['breed'] as String?,
      neutered: (json['neutered'] as bool?) ?? false,
      indoor: (json['indoor'] as bool?) ?? true,
      color: json['color'] as String?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      allergies: _stringList(json['allergies']),
      diseases: _stringList(json['diseases']),
      medications: _stringList(json['medications']),
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?,
      themeAccentHex: json['themeAccentHex'] as String?,
      priorities: _stringList(json['priorities']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}
