/// Safety guidance for a known cat hazard. Stored at
/// `content/safety/{id}`.
class SafetyGuidance {
  const SafetyGuidance({
    required this.id,
    required this.title,
    required this.severity,
    this.summary,
    this.body,
    this.symptoms = const <String>[],
    this.immediateActions = const <String>[],
    this.source,
    this.missingData = true,
  });

  final String id;
  final String title;

  /// `low`, `medium`, `high`, `critical`.
  final String severity;
  final String? summary;
  final String? body;
  final List<String> symptoms;
  final List<String> immediateActions;
  final String? source;
  final bool missingData;

  SafetyGuidance copyWith({
    String? id,
    String? title,
    String? severity,
    String? summary,
    String? body,
    List<String>? symptoms,
    List<String>? immediateActions,
    String? source,
    bool? missingData,
  }) {
    return SafetyGuidance(
      id: id ?? this.id,
      title: title ?? this.title,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      body: body ?? this.body,
      symptoms: symptoms ?? this.symptoms,
      immediateActions: immediateActions ?? this.immediateActions,
      source: source ?? this.source,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'severity': severity,
        'summary': summary,
        'body': body,
        'symptoms': symptoms,
        'immediateActions': immediateActions,
        'source': source,
        'missingData': missingData,
      };

  factory SafetyGuidance.fromJson(Map<String, dynamic> json) {
    return SafetyGuidance(
      id: json['id'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      summary: json['summary'] as String?,
      body: json['body'] as String?,
      symptoms: _stringList(json['symptoms']),
      immediateActions: _stringList(json['immediateActions']),
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
