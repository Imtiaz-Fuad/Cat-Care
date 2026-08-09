/// A specific vaccination administered to a cat. Stored at
/// `users/{uid}/cats/{catId}/vaccinations/{vaccinationId}`.
///
/// `vaccineCode` references a `VaccineInfo` content model (e.g. `FVRCP`).
/// `nextDue` is computed by `VaccinationManager` from cadence in `VaccineInfo`.
class Vaccination {
  const Vaccination({
    required this.id,
    required this.catId,
    required this.vaccineCode,
    required this.administeredAt,
    this.nextDue,
    this.batchNumber,
    this.vetName,
    this.notes,
    this.reminderEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String catId;
  final String vaccineCode;
  final DateTime administeredAt;
  final DateTime? nextDue;
  final String? batchNumber;
  final String? vetName;
  final String? notes;
  final bool reminderEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vaccination copyWith({
    String? id,
    String? catId,
    String? vaccineCode,
    DateTime? administeredAt,
    DateTime? nextDue,
    String? batchNumber,
    String? vetName,
    String? notes,
    bool? reminderEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vaccination(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      vaccineCode: vaccineCode ?? this.vaccineCode,
      administeredAt: administeredAt ?? this.administeredAt,
      nextDue: nextDue ?? this.nextDue,
      batchNumber: batchNumber ?? this.batchNumber,
      vetName: vetName ?? this.vetName,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'vaccineCode': vaccineCode,
        'administeredAt': administeredAt.toIso8601String(),
        'nextDue': nextDue?.toIso8601String(),
        'batchNumber': batchNumber,
        'vetName': vetName,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id'] as String,
      catId: json['catId'] as String,
      vaccineCode: json['vaccineCode'] as String,
      administeredAt: DateTime.parse(json['administeredAt'] as String),
      nextDue: _parseDate(json['nextDue']),
      batchNumber: json['batchNumber'] as String?,
      vetName: json['vetName'] as String?,
      notes: json['notes'] as String?,
      reminderEnabled: (json['reminderEnabled'] as bool?) ?? true,
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
