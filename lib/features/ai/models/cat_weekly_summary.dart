/// Pre-aggregated, Gemini-friendly snapshot of the past [days] days of
/// activity for a single cat.
///
/// Why pre-aggregate?
///   * The model only needs derived metrics (counts, totals, trends)
///     to write a useful weekly report — never the raw logs.
///   * Trimming to metrics keeps the prompt under Gemini's free-tier
///     context budget even after the cat has been used for months.
///   * Building the summary on-device means we do NOT need a Cloud
///     Function in the loop, which is critical because the Firebase
///     project is on the Spark (free) plan.
///
/// This is a deliberately **simpler** version of the original
/// `functions/src/cat_summary.ts`. The TS implementation also
/// reported `routineCompletionPct`, `activeMedications`, and
/// `upcomingVaccinations`; those fields are skipped for MVP because
/// pulling them in would require three more repositories, three more
/// UI guarantees about activity streams being ready, and a longer
/// per-call latency budget. See `docs/CLIENT_GEMINI_KEY.md` §"MVP
/// scope limitations" for the upgrade path.
class CatWeeklySummary {
  const CatWeeklySummary({
    required this.daysWindow,
    required this.feedingCount,
    required this.totalFeedingAmount,
    required this.waterCount,
    required this.totalWaterMl,
    required this.lastWeights,
    required this.feedingDaysWithLogs,
    required this.waterDaysWithLogs,
  });

  /// Window in days that was aggregated (typically 7).
  final int daysWindow;

  /// Total number of feeding entries inside the window.
  final int feedingCount;

  /// Sum of `amount` across every feeding entry inside the window.
  /// Units are mixed (grams + cups + cans) so this is intentionally a
  /// raw sum — the prompt tells Gemini to treat the number as
  /// approximate.
  final double totalFeedingAmount;

  /// Total number of water entries inside the window.
  final int waterCount;

  /// Sum of `amountMl` across every water entry inside the window.
  final double totalWaterMl;

  /// Last [max] weight entries, newest-first. Length is bounded so the
  /// prompt stays small even for heavy users.
  final List<WeightPoint> lastWeights;

  /// Number of distinct days (in the window) with at least one
  /// feeding entry. 0..[daysWindow].
  final int feedingDaysWithLogs;

  /// Number of distinct days (in the window) with at least one water
  /// entry. 0..[daysWindow].
  final int waterDaysWithLogs;

  /// True when there is *no* data worth summarising — i.e. zero
  /// feedings, zero water, and zero weights in the window. The weekly
  /// report UI short-circuits to the static "Not enough data yet"
  /// card when this is true so we never burn the free-tier quota on
  /// a model call.
  bool get isEmpty =>
      feedingCount == 0 && waterCount == 0 && lastWeights.isEmpty;

  /// Stable, human-readable render used by the prompt and by debug
  /// logs. Bounded to the values Gemini actually consumes so the log
  /// line stays short.
  @override
  String toString() =>
      'CatWeeklySummary(window=$daysWindow, '
      'feedings=$feedingCount, water=$waterCount, '
      'totalGrams=${totalFeedingAmount.toStringAsFixed(1)}, '
      'totalMl=${totalWaterMl.toStringAsFixed(1)}, '
      'weights=${lastWeights.length})';
}

/// One weight data-point carried in [CatWeeklySummary.lastWeights].
class WeightPoint {
  const WeightPoint({required this.recordedAt, required this.kg});

  final DateTime recordedAt;
  final double kg;
}
