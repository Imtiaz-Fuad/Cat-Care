/// Emergency guidance reference. Stored at `content/emergency/{id}`.
///
/// The UI must never use this to diagnose — only to nudge the user to
/// contact a vet (per PRD §8 / guardrails).
class EmergencyGuidance {
  const EmergencyGuidance({
    required this.id,
    required this.title,
    required this.severity,
    this.summary,
    this.signs = const <String>[],
    this.doNow = const <String>[],
    this.doNot = const <String>[],
    this.contactVetImmediately = true,
    this.source,
    this.missingData = true,
  });

  final String id;
  final String title;

  /// `urgent`, `critical`, `monitor`.
  final String severity;
  final String? summary;
  final List<String> signs;
  final List<String> doNow;
  final List<String> doNot;
  final bool contactVetImmediately;
  final String? source;
  final bool missingData;

  EmergencyGuidance copyWith({
    String? id,
    String? title,
    String? severity,
    String? summary,
    List<String>? signs,
    List<String>? doNow,
    List<String>? doNot,
    bool? contactVetImmediately,
    String? source,
    bool? missingData,
  }) {
    return EmergencyGuidance(
      id: id ?? this.id,
      title: title ?? this.title,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      signs: signs ?? this.signs,
      doNow: doNow ?? this.doNow,
      doNot: doNot ?? this.doNot,
      contactVetImmediately:
          contactVetImmediately ?? this.contactVetImmediately,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'severity': severity,
        'summary': summary,
        'signs': signs,
        'doNow': doNow,
        'doNot': doNot,
        'contactVetImmediately': contactVetImmediately,
        'source': source,
        'missingData': missingData,
      };

  factory EmergencyGuidance.fromJson(Map<String, dynamic> json) {
    return EmergencyGuidance(
      id: json['id'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      summary: json['summary'] as String?,
      signs: _stringList(json['signs']),
      doNow: _stringList(json['doNow']),
      doNot: _stringList(json['doNot']),
      contactVetImmediately:
          (json['contactVetImmediately'] as bool?) ?? true,
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
