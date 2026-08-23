import '../../../core/models/content/vaccine_info.dart';
import '../../../core/models/vaccination.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/content/content_repository.dart';

/// Pure-logic derivation of `nextDue` for a vaccination, plus the
/// "what's overdue / coming up soon" views for the dashboard chips.
///
/// The manager only knows about [Vaccination] and [VaccineInfo] — it
/// never touches Firestore directly. The repository stream provides
/// the data; the UI asks this manager for sorted / filtered views.
class VaccinationManager {
  VaccinationManager({
    required ContentRepository contentRepository,
    DateTime Function()? clock,
  }) : _content = contentRepository,
       _clock = clock ?? DateTime.now;

  final ContentRepository _content;
  final DateTime Function() _clock;

  /// Compute the next due date for a vaccination given the cadence
  /// stored on [VaccineInfo.boosterIntervalDays].
  ///
  /// Returns `null` when [info] or its cadence is missing — the UI
  /// then renders an "unknown" chip rather than fabricating a date.
  DateTime? nextDue({
    required Vaccination vaccination,
    required VaccineInfo? info,
  }) {
    if (info == null) return null;
    if (info.boosterIntervalDays <= 0) return null;
    return vaccination.administeredAt.add(
      Duration(days: info.boosterIntervalDays),
    );
  }

  /// Async helper: resolve the [VaccineInfo] for [vaccination] via
  /// the content layer and return the next due date.
  Future<DateTime?> nextDueResolved(Vaccination vaccination) async {
    try {
      final VaccineInfo? info = await _content.getVaccineInfo(
        vaccination.vaccineCode,
      );
      return nextDue(vaccination: vaccination, info: info);
    } catch (error, stack) {
      AppLogger.w('VaccinationManager.nextDueResolved failed', error, stack);
      return null;
    }
  }

  /// Partition [vaccinations] into overdue + upcoming given a fresh
  /// snapshot of [infoByCode] (vaccineCode → VaccineInfo). The UI
  /// uses this for the "Health" tab summary cards.
  ///
  /// Overdue = `nextDue` is strictly before "now".
  /// Upcoming = `nextDue` is within [horizonDays] from "now".
  VaccinationSummary summarize({
    required List<Vaccination> vaccinations,
    required Map<String, VaccineInfo> infoByCode,
    int horizonDays = 30,
  }) {
    final DateTime now = _clock();
    final DateTime horizon = now.add(Duration(days: horizonDays));

    final List<Vaccination> overdue = <Vaccination>[];
    final List<Vaccination> upcoming = <Vaccination>[];
    for (final Vaccination v in vaccinations) {
      final VaccineInfo? info = infoByCode[v.vaccineCode];
      final DateTime? due = nextDue(vaccination: v, info: info);
      if (due == null) continue;
      if (due.isBefore(now)) {
        overdue.add(v);
      } else if (!due.isAfter(horizon)) {
        upcoming.add(v);
      }
    }
    overdue.sort((a, b) => a.administeredAt.compareTo(b.administeredAt));
    upcoming.sort((a, b) => a.administeredAt.compareTo(b.administeredAt));
    return VaccinationSummary(overdue: overdue, upcoming: upcoming);
  }
}

/// Immutable view surfaced by [VaccinationManager.summarize].
class VaccinationSummary {
  const VaccinationSummary({required this.overdue, required this.upcoming});

  final List<Vaccination> overdue;
  final List<Vaccination> upcoming;

  bool get hasOverdue => overdue.isNotEmpty;
  bool get hasUpcoming => upcoming.isNotEmpty;
  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty;
}
