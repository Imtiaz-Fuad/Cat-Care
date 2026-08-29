import '../../../core/models/feeding_entry.dart';
import '../../../core/models/water_entry.dart';
import '../../../core/models/weight_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../nutrition/repositories/feeding_repository.dart';
import '../../nutrition/repositories/water_repository.dart';
import '../../health/repositories/weight_repository.dart';
import '../models/cat_weekly_summary.dart';

/// Builds a [CatWeeklySummary] by querying the three repositories that
/// already own a `getForRange` helper.
///
/// Kept intentionally narrow: it does **not** aggregate routine
/// completion, active medications, or upcoming vaccinations (see
/// `docs/RESTRICT_KEY.md` §"MVP scope"). Adding those would require
/// three more repositories, three more "is the stream ready" checks,
/// and a noticeably longer per-call latency budget on slow devices —
/// none of which are worth the marginal gain in prompt quality for a
/// 7-day summary.
class CatSummaryBuilder {
  CatSummaryBuilder({
    required FeedingRepository feedingRepository,
    required WaterRepository waterRepository,
    required WeightRepository weightRepository,
    DateTime Function()? clock,
    int? maxLastWeights,
  }) : _feeding = feedingRepository,
       _water = waterRepository,
       _weights = weightRepository,
       _clock = clock ?? DateTime.now,
       _maxLastWeights = maxLastWeights ?? 4;

  final FeedingRepository _feeding;
  final WaterRepository _water;
  final WeightRepository _weights;
  final DateTime Function() _clock;
  final int _maxLastWeights;

  /// Aggregate the past [days] days of activity for [ownerId]'s [catId].
  ///
  /// Returns a summary with `isEmpty == true` (not `null`) when there
  /// is nothing in the window — callers should short-circuit to the
  /// "Not enough data yet" UI and skip the model call.
  Future<CatWeeklySummary> build({
    required String ownerId,
    required String catId,
    int days = 7,
  }) async {
    final DateTime now = _clock();
    final DateTime since = now.subtract(Duration(days: days));

    // Fire all three queries in parallel; each repository's
    // `getForRange` is already rate-limited by Firestore indexes.
    final List<FeedingEntry> feedings = await _feeding.getFeedings(
      ownerId: ownerId,
      catId: catId,
      since: since,
    );
    final List<WaterEntry> water = await _water.getWater(
      ownerId: ownerId,
      catId: catId,
      since: since,
    );
    final List<WeightEntry> weights = await _weights.getWeightsForRange(
      ownerId: ownerId,
      catId: catId,
      since: since,
    );

    double totalFeedingAmount = 0;
    final Set<String> feedingDays = <String>{};
    for (final FeedingEntry e in feedings) {
      totalFeedingAmount += e.amount;
      feedingDays.add(_dayKey(e.time));
    }

    double totalWaterMl = 0;
    final Set<String> waterDays = <String>{};
    for (final WaterEntry e in water) {
      totalWaterMl += e.amountMl;
      waterDays.add(_dayKey(e.time));
    }

    final List<WeightPoint> lastWeights = weights
        .take(_maxLastWeights)
        .map(
          (WeightEntry w) =>
              WeightPoint(recordedAt: w.recordedAt, kg: w.weightKg),
        )
        .toList(growable: false);

    final CatWeeklySummary summary = CatWeeklySummary(
      daysWindow: days,
      feedingCount: feedings.length,
      totalFeedingAmount: totalFeedingAmount,
      waterCount: water.length,
      totalWaterMl: totalWaterMl,
      lastWeights: lastWeights,
      feedingDaysWithLogs: feedingDays.length,
      waterDaysWithLogs: waterDays.length,
    );
    AppLogger.i('CatSummaryBuilder.build $ownerId/$catId -> $summary');
    return summary;
  }

  /// Bucket a [DateTime] into a stable YYYY-MM-DD key (local time so
  /// the count matches the user's calendar view).
  static String _dayKey(DateTime t) {
    final DateTime local = t.toLocal();
    final String y = local.year.toString().padLeft(4, '0');
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
