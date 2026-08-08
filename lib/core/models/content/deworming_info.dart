/// Deworming protocol reference. Stored at `content/deworming/{id}`.
///
/// `intervalDays` is the cadence between doses. `scheduleMonths` is the
/// list of life-stage months at which a dose is recommended.
class DewormingInfo {
  const DewormingInfo({
    required this.id,
    required this.label,
    required this.intervalDays,
    this.scheduleMonths = const <int>[],
    this.notes,
    this.source,
    this.missingData = true,
  });

  final String id;
  final String label;
  final int intervalDays;
  final List<int> scheduleMonths;
  final String? notes;
  final String? source;
  final bool missingData;

  DewormingInfo copyWith({
    String? id,
    String? label,
    int? intervalDays,
    List<int>? scheduleMonths,
    String? notes,
    String? source,
    bool? missingData,
  }) {
    return DewormingInfo(
      id: id ?? this.id,
      label: label ?? this.label,
      intervalDays: intervalDays ?? this.intervalDays,
      scheduleMonths: scheduleMonths ?? this.scheduleMonths,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'intervalDays': intervalDays,
        'scheduleMonths': scheduleMonths,
        'notes': notes,
        'source': source,
        'missingData': missingData,
      };

  factory DewormingInfo.fromJson(Map<String, dynamic> json) {
    return DewormingInfo(
      id: json['id'] as String,
      label: json['label'] as String,
      intervalDays: (json['intervalDays'] as num).toInt(),
      scheduleMonths: _intList(json['scheduleMonths']),
      notes: json['notes'] as String?,
      source: json['source'] as String?,
      missingData: (json['missingData'] as bool?) ?? true,
    );
  }
}

List<int> _intList(Object? value) {
  if (value is List) {
    return value.whereType<num>().map((num n) => n.toInt()).toList();
  }
  return const <int>[];
}
