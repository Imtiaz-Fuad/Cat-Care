/// Life-stage classification used to seed routines, tailor nutrition advice,
/// and shape AI prompts. Boundaries per the implementation plan:
///
/// - `kitten`:  up to 6 months
/// - `junior`:  6 months up to 1 year
/// - `adult`:   1 year up to 7 years
/// - `mature`:  7 years up to 11 years
/// - `senior`:  11 years and older
///
/// `fromBirthday` uses whole **months** between the birthday and [today].
/// The lower bound of a stage is inclusive, the upper bound is exclusive
/// (e.g. a 6-month-old cat is `junior`, a 12-month-old cat is `adult`).
enum CatLifeStage {
  kitten,
  junior,
  adult,
  mature,
  senior;

  /// Stable storage key (snake-case) used in Firestore documents.
  String get storageKey {
    switch (this) {
      case CatLifeStage.kitten:
        return 'kitten';
      case CatLifeStage.junior:
        return 'junior';
      case CatLifeStage.adult:
        return 'adult';
      case CatLifeStage.mature:
        return 'mature';
      case CatLifeStage.senior:
        return 'senior';
    }
  }

  /// Human-readable label used by the UI. English only — localized copies
  /// live in `lib/l10n/app_en.arb` (Phase 8) and look these keys up.
  String get displayLabel {
    switch (this) {
      case CatLifeStage.kitten:
        return 'Kitten';
      case CatLifeStage.junior:
        return 'Junior';
      case CatLifeStage.adult:
        return 'Adult';
      case CatLifeStage.mature:
        return 'Mature';
      case CatLifeStage.senior:
        return 'Senior';
    }
  }

  /// Derive a stage from a birthday. Returns `adult` for null inputs so
  /// callers that lack a birth date still get sensible defaults.
  ///
  /// Edge cases:
  /// - Birthday in the future (e.g. stray with estimated birth date) →
  ///   clamped to `kitten`.
  /// - Birthday exactly N years ago at today → next stage up.
  static CatLifeStage fromBirthday(DateTime? birthday, {DateTime? now}) {
    if (birthday == null) return CatLifeStage.adult;
    final today = now ?? DateTime.now();
    final months = _monthsBetween(birthday, today);
    if (months < 6) return CatLifeStage.kitten;
    if (months < 12) return CatLifeStage.junior;
    final years = months / 12;
    if (years < 7) return CatLifeStage.adult;
    if (years < 11) return CatLifeStage.mature;
    return CatLifeStage.senior;
  }

  /// Parse a Firestore-stored key. Unknown values fall back to `adult`.
  static CatLifeStage fromStorageKey(String? key) {
    if (key == null) return CatLifeStage.adult;
    for (final stage in CatLifeStage.values) {
      if (stage.storageKey == key) return stage;
    }
    return CatLifeStage.adult;
  }

  /// Total whole months between [start] and [end]. Negative when the
  /// birthday is in the future (clamped callers should treat as 0).
  static int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    return months;
  }
}
