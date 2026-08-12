import '../../../core/models/cat_profile.dart';

/// The priority tags the user can opt into during onboarding. Stored
/// as a `List<String>` on [CatProfile.priorities]. The set drives
/// which default routines `RoutineGeneratorService` seeds in Phase 4.
///
/// Values are stable identifiers — UI layers (Phase 8 i18n) may map
/// these to localized labels but the underlying code never changes.
class CatPriority {
  CatPriority._();

  static const String routine = 'routine';
  static const String nutrition = 'nutrition';
  static const String grooming = 'grooming';
  static const String health = 'health';
  static const String vaccinations = 'vaccinations';

  /// Full list, exposed for chips/checkboxes.
  static const List<String> all = <String>[
    routine,
    nutrition,
    grooming,
    health,
    vaccinations,
  ];
}

/// A working draft of a [CatProfile] collected during onboarding.
///
/// Onboarding builds one of these step-by-step (photo → name → details
/// → priorities) and converts it into a [CatProfile] only when the
/// user taps "Done" on the final step. Storing the working state as a
/// value object (rather than mutating fields on a half-formed profile)
/// keeps the form easy to test and to navigate forward / back through
/// without losing data.
class CatDraft {
  CatDraft({
    this.name = '',
    this.photoPath,
    this.photoUrl,
    this.accentHex,
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
    this.priorities = const <String>[],
  });

  final String name;

  /// Local path of the picked-but-not-yet-uploaded photo (if any).
  /// Used by the UI to render a preview before upload completes.
  final String? photoPath;

  /// Download URL of the photo once it has been uploaded by
  /// `CatRepository.uploadPhoto`.
  final String? photoUrl;

  /// Hex-formatted `#RRGGBB` accent derived from the photo. May be
  /// `null` when no photo was picked.
  final String? accentHex;

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
  final List<String> priorities;

  /// Whether the draft has the minimum data the repository needs to
  /// create a profile (name required per onboarding step 2).
  bool get isValid => name.trim().isNotEmpty;

  CatDraft copyWith({
    String? name,
    Object? photoPath = _sentinel,
    Object? photoUrl = _sentinel,
    Object? accentHex = _sentinel,
    Object? birthday = _sentinel,
    Object? sex = _sentinel,
    Object? breed = _sentinel,
    bool? neutered,
    bool? indoor,
    Object? color = _sentinel,
    Object? weightKg = _sentinel,
    List<String>? allergies,
    List<String>? diseases,
    List<String>? medications,
    Object? notes = _sentinel,
    List<String>? priorities,
  }) {
    return CatDraft(
      name: name ?? this.name,
      photoPath: identical(photoPath, _sentinel)
          ? this.photoPath
          : photoPath as String?,
      photoUrl: identical(photoUrl, _sentinel)
          ? this.photoUrl
          : photoUrl as String?,
      accentHex: identical(accentHex, _sentinel)
          ? this.accentHex
          : accentHex as String?,
      birthday: identical(birthday, _sentinel)
          ? this.birthday
          : birthday as DateTime?,
      sex: identical(sex, _sentinel) ? this.sex : sex as String?,
      breed: identical(breed, _sentinel) ? this.breed : breed as String?,
      neutered: neutered ?? this.neutered,
      indoor: indoor ?? this.indoor,
      color: identical(color, _sentinel) ? this.color : color as String?,
      weightKg: identical(weightKg, _sentinel)
          ? this.weightKg
          : weightKg as double?,
      allergies: allergies ?? this.allergies,
      diseases: diseases ?? this.diseases,
      medications: medications ?? this.medications,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      priorities: priorities ?? this.priorities,
    );
  }

  /// Build a [CatProfile] from this draft.
  ///
  /// [id] and [ownerId] are injected by the repository — onboarding
  /// never sees those values.
  CatProfile toProfile({
    required String id,
    required String ownerId,
    DateTime? now,
  }) {
    final DateTime created = now ?? DateTime.now();
    return CatProfile(
      id: id,
      ownerId: ownerId,
      name: name.trim(),
      birthday: birthday,
      sex: sex,
      breed: breed,
      neutered: neutered,
      indoor: indoor,
      color: color,
      weightKg: weightKg,
      allergies: List<String>.unmodifiable(allergies),
      diseases: List<String>.unmodifiable(diseases),
      medications: List<String>.unmodifiable(medications),
      notes: notes,
      photoUrl: photoUrl,
      themeAccentHex: accentHex,
      priorities: List<String>.unmodifiable(priorities),
      createdAt: created,
      updatedAt: created,
    );
  }
}

const Object _sentinel = Object();
