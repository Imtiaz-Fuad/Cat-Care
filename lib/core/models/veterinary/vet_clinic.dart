/// A vet clinic entry — either curated in `vet_clinics` or pulled from
/// Google Places (Phase 6). Curated entries are verified by admins; Place
/// entries are flagged with `verified = false` and may carry a `placeId`.
class VetClinic {
  const VetClinic({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.openingHours,
    this.isEmergency = false,
    this.verified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.placeId,
    this.source = 'curated',
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final String? openingHours;
  final bool isEmergency;
  final bool verified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? placeId;

  /// `curated` or `places_api` — used by the UI to display a source chip.
  final String source;

  VetClinic copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? phone,
    String? openingHours,
    bool? isEmergency,
    bool? verified,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? placeId,
    String? source,
  }) {
    return VetClinic(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
      isEmergency: isEmergency ?? this.isEmergency,
      verified: verified ?? this.verified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      placeId: placeId ?? this.placeId,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'phone': phone,
        'openingHours': openingHours,
        'isEmergency': isEmergency,
        'verified': verified,
        'verifiedBy': verifiedBy,
        'verifiedAt': verifiedAt?.toIso8601String(),
        'placeId': placeId,
        'source': source,
      };

  factory VetClinic.fromJson(Map<String, dynamic> json) {
    return VetClinic(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      phone: json['phone'] as String?,
      openingHours: json['openingHours'] as String?,
      isEmergency: (json['isEmergency'] as bool?) ?? false,
      verified: (json['verified'] as bool?) ?? false,
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: _parseDate(json['verifiedAt']),
      placeId: json['placeId'] as String?,
      source: (json['source'] as String?) ?? 'curated',
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
