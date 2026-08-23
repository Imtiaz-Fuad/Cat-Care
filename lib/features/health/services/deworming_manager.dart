import '../../../core/models/content/deworming_info.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/content/content_repository.dart';

/// Tracks the last administered date per deworming protocol and
/// returns whether a dose is due. Backed entirely by content + a
/// caller-provided `lastDosedAt` map (no persistence of its own — the
/// UI persists its own `lastDosedAt` per protocol).
class DewormingManager {
  DewormingManager({
    required ContentRepository contentRepository,
    DateTime Function()? clock,
  })  : _content = contentRepository,
        _clock = clock ?? DateTime.now;

  final ContentRepository _content;
  final DateTime Function() _clock;

  /// Return `true` when the next dose should be administered "soon"
  /// (within [warningWindowDays]) or is already overdue.
  bool isDue({
    required DewormingInfo info,
    required DateTime? lastDosedAt,
    int warningWindowDays = 7,
  }) {
    if (lastDosedAt == null) return true;
    final DateTime now = _clock();
    final DateTime dueAt =
        lastDosedAt.add(Duration(days: info.intervalDays));
    return !dueAt.isAfter(now.add(Duration(days: warningWindowDays)));
  }

  /// Convenience helper: same as [isDue] but resolves the protocol
  /// info via the content layer.
  Future<bool> isDueResolved({
    required String protocolId,
    required DateTime? lastDosedAt,
    int warningWindowDays = 7,
  }) async {
    try {
      final DewormingInfo? info = await _content.getDewormingInfo(protocolId);
      if (info == null) return false;
      return isDue(
        info: info,
        lastDosedAt: lastDosedAt,
        warningWindowDays: warningWindowDays,
      );
    } catch (error, stack) {
      AppLogger.w('DewormingManager.isDueResolved failed', error, stack);
      return false;
    }
  }

  /// Compute the date when the next dose will be due given the last
  /// dose date. Returns `null` when [lastDosedAt] is missing so the
  /// UI can render "Never dosed" instead of guessing.
  DateTime? nextDue({
    required DewormingInfo info,
    required DateTime? lastDosedAt,
  }) {
    if (lastDosedAt == null) return null;
    return lastDosedAt.add(Duration(days: info.intervalDays));
  }
}