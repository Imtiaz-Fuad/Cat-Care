/// A captured health-event for a cat — typically a vet visit. Stored at
/// `users/{uid}/cats/{catId}/health/{recordId}`. Files live in Firebase
/// Storage under `users/{uid}/cats/{catId}/health/{recordId}/{fileName}`
/// and are referenced by URL in `fileAttachments`.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.catId,
    required this.title,
    required this.recordedAt,
    this.diagnosis,
    this.prescription,
    this.medicines = const <String>[],
    this.vaccines = const <String>[],
    this.tests = const <String>[],
    this.fileAttachments = const <String>[],
    this.vetName,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String catId;
  final String title;
  final DateTime recordedAt;
  final String? diagnosis;
  final String? prescription;
  final List<String> medicines;
  final List<String> vaccines;
  final List<String> tests;
  final List<String> fileAttachments;
  final String? vetName;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HealthRecord copyWith({
    String? id,
    String? catId,
    String? title,
    DateTime? recordedAt,
    String? diagnosis,
    String? prescription,
    List<String>? medicines,
    List<String>? vaccines,
    List<String>? tests,
    List<String>? fileAttachments,
    String? vetName,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      title: title ?? this.title,
      recordedAt: recordedAt ?? this.recordedAt,
      diagnosis: diagnosis ?? this.diagnosis,
      prescription: prescription ?? this.prescription,
      medicines: medicines ?? this.medicines,
      vaccines: vaccines ?? this.vaccines,
      tests: tests ?? this.tests,
      fileAttachments: fileAttachments ?? this.fileAttachments,
      vetName: vetName ?? this.vetName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'catId': catId,
        'title': title,
        'recordedAt': recordedAt.toIso8601String(),
        'diagnosis': diagnosis,
        'prescription': prescription,
        'medicines': medicines,
        'vaccines': vaccines,
        'tests': tests,
        'fileAttachments': fileAttachments,
        'vetName': vetName,
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String,
      catId: json['catId'] as String,
      title: json['title'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      diagnosis: json['diagnosis'] as String?,
      prescription: json['prescription'] as String?,
      medicines: _stringList(json['medicines']),
      vaccines: _stringList(json['vaccines']),
      tests: _stringList(json['tests']),
      fileAttachments: _stringList(json['fileAttachments']),
      vetName: json['vetName'] as String?,
      notes: json['notes'] as String?,
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
