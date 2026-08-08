/// Vaccine reference info. Stored at `content/vaccine/{code}`.
///
/// `boosterIntervalDays` powers `VaccinationManager.nextDue` in Phase 5.
class VaccineInfo {
  const VaccineInfo({
    required this.code,
    required this.name,
    required this.description,
    required this.boosterIntervalDays,
    this.minAgeWeeks,
    this.core = true,
    this.speciesNotes,
    this.source,
    this.missingData = true,
  });

  final String code;
  final String name;
  final String description;
  final int boosterIntervalDays;
  final int? minAgeWeeks;
  final bool core;

  /// Free-form notes per species or breed (e.g. indoor-only cats).
  final String? speciesNotes;
  final String? source;
  final bool missingData;

  VaccineInfo copyWith({
    String? code,
    String? name,
    String? description,
    int? boosterIntervalDays,
    int? minAgeWeeks,
    bool? core,
    String? speciesNotes,
    String? source,
    bool? missingData,
  }) {
    return VaccineInfo(
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      boosterIntervalDays: boosterIntervalDays ?? this.boosterIntervalDays,
      minAgeWeeks: minAgeWeeks ?? this.minAgeWeeks,
      core: core ?? this.core,
      speciesNotes: speciesNotes ?? this.speciesNotes,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
        'description': description,
        'boosterIntervalDays': boosterIntervalDays,
        'minAgeWeeks': minAgeWeeks,
        'core': core,
        'speciesNotes': speciesNotes,
        'source': source,
        'missingData': missingData,
      };

  factory VaccineInfo.fromJson(Map<String, dynamic> json) {
    return VaccineInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      boosterIntervalDays: (json['boosterIntervalDays'] as num).toInt(),
      minAgeWeeks: (json['minAgeWeeks'] as num?)?.toInt(),
      core: (json['core'] as bool?) ?? true,
      speciesNotes: json['speciesNotes'] as String?,
      source: json['source'] as String?,
      missingData: (json['missingData'] as bool?) ?? true,
    );
  }
}
