import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/notification_schedule.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/notification_service.dart';
import '../../cats/providers/cat_provider.dart';
import '../../routine/providers/routine_provider.dart';
import '../repositories/notification_schedule_repository.dart';

/// Reactive bridge between routine data and the OS-level
/// notification surface.
///
/// Watches [RoutineProvider.routines] for the active cat. For every
/// task with `reminder == true` and a `timeOfDay`, this service
/// upserts a [NotificationSchedule] doc and calls
/// [NotificationService.schedule]. For tasks without a reminder
/// (or where the reminder was just turned off), it cancels the
/// local notification + deletes the doc.
///
/// The contract:
///   * one OS-level notification per `routineTaskId` (the schedule
///     doc id is `routine:` + taskId so it's stable across edits).
///   * deleting a routine cancels its notification synchronously.
///   * sign-out cancels all notifications and clears Firestore
///     schedules via [signOut].
class NotificationSchedulerService extends ChangeNotifier {
  NotificationSchedulerService({
    required NotificationScheduleRepository repository,
    required NotificationService notificationService,
    required RoutineProvider routineProvider,
    required CatProvider catProvider,
    DateTime Function()? clock,
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // ignore: prefer_initializing_formals
       _notificationService = notificationService,
       // ignore: prefer_initializing_formals
       _routineProvider = routineProvider,
       // ignore: prefer_initializing_formals
       _catProvider = catProvider,
       _clock = clock ?? DateTime.now {
    _routineProvider.addListener(_handleRoutinesChanged);
    _listenerHandles.add(_handleRoutinesChanged);
    _catProvider.addListener(_handleCatChanged);
    _listenerHandles.add(_handleCatChanged);
  }

  final NotificationScheduleRepository _repository;
  final NotificationService _notificationService;
  final RoutineProvider _routineProvider;
  final CatProvider _catProvider;
  final DateTime Function() _clock;

  final List<VoidCallback> _listenerHandles = <VoidCallback>[];

  bool _busy = false;

  bool get isBusy => _busy;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Run a full sync once on the next tick. Useful for the auth
  /// bootstrap path and after sign-in.
  Future<void> syncNow() => _sync();

  /// Cancel everything the scheduler scheduled. Called on sign-out.
  Future<void> cancelAll() async {
    await _notificationService.cancelAll();
    final String? uid = _catProvider.profile?.uid;
    if (uid != null) {
      try {
        await _repository.deleteAllForOwner(ownerId: uid);
      } catch (error, stack) {
        AppLogger.w(
          'NotificationScheduler.cancelAll: cleanup failed',
          error,
          stack,
        );
      }
    }
  }

  /// Drop all scheduled notifications. Alias for [cancelAll] used
  /// during guest sign-out.
  Future<void> signOut() => cancelAll();

  /// Convert a stable source key into a 32-bit signed int suitable
  /// for the OS notification id. Exposed so tests can pin ids.
  static int idForKey(String key) {
    int hash = 0;
    for (final int code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _handleRoutinesChanged() {
    // The provider fires for both list + error events. We only care
    // about the data shape; ignore the callback if there's no active
    // owner (the auth listener will catch the next sign-in).
    if (_catProvider.profile?.uid == null) return;
    _sync();
  }

  void _handleCatChanged() {
    final String? uid = _catProvider.profile?.uid;
    if (uid == null) {
      _notificationService.cancelAll();
    } else {
      _sync();
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    final String? uid = _catProvider.profile?.uid;
    if (uid == null) return;
    _busy = true;
    try {
      await _notificationService.initialize();
      final List<RoutineTask> tasks = _routineProvider.routines;
      final List<_Planned> planned = <_Planned>[];
      for (final RoutineTask task in tasks) {
        final _Planned? p = _planFromTask(task);
        if (p != null) planned.add(p);
      }

      // 1. Apply every desired schedule.
      for (final _Planned p in planned) {
        await _repository.upsert(ownerId: uid, schedule: p.schedule);
        await _notificationService.schedule(
          id: p.notificationId,
          title: p.schedule.title,
          body: p.schedule.body,
          when: p.schedule.fireAt,
          payload: p.schedule.payload,
        );
      }

      // 2. Cancel any persisted schedule that no longer corresponds
      //    to a reminder (deleted task, reminder turned off, etc.).
      // Fire-and-forget: cleanup runs in parallel with the rest of the
      // sync; failures are logged inside [_pruneStale].
      // ignore: unawaited_futures
      _pruneStale(uid: uid, keep: planned);
    } catch (error, stack) {
      AppLogger.w('NotificationScheduler.sync failed', error, stack);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  _Planned? _planFromTask(RoutineTask task) {
    if (!task.reminder) return null;
    final DateTime? tod = task.timeOfDay;
    if (tod == null) return null;
    final String? catId = _catProvider.activeCatId;
    if (catId == null) return null;

    final DateTime now = _clock();
    final DateTime fire = _nextOccurrence(tod, now);
    final String key = 'routine:${task.id}';
    final NotificationSchedule schedule = NotificationSchedule(
      id: key,
      catId: catId,
      channelKey: AppConstants.notificationsChannelRoutine,
      title: '${task.title} \u2014 ${_catProvider.activeCat?.name ?? 'Cat'}',
      body: 'Time for ${task.title.toLowerCase()}.',
      fireAt: fire,
      payload: 'routine/${task.id}',
      sourceType: 'routine',
      sourceId: task.id,
    );
    return _Planned(
      key: key,
      schedule: schedule,
      notificationId: idForKey(key),
    );
  }

  /// Advance `timeOfDay` to the next occurrence strictly after [now].
  static DateTime _nextOccurrence(DateTime timeOfDay, DateTime now) {
    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (today.isAfter(now)) return today;
    return today.add(const Duration(days: 1));
  }

  Future<void> _pruneStale({
    required String uid,
    required List<_Planned> keep,
  }) async {
    final Set<String> keepKeys = keep.map((p) => p.key).toSet();

    try {
      // Pull the latest snapshot from Firestore directly so we don't
      // accidentally fight a stale stream-state.
      // We can't re-use the repository stream here without exposing
      // it; doing a one-shot read is fine for this small collection.
      final stream = _repository.watchSchedules(ownerId: uid);
      final List<NotificationSchedule> existing = await stream.first;
      for (final NotificationSchedule s in existing) {
        if (keepKeys.contains(s.id)) continue;
        await _repository.delete(ownerId: uid, scheduleId: s.id);
        await _notificationService.cancel(idForKey(s.id));
      }
    } catch (error, stack) {
      AppLogger.w('NotificationScheduler.pruneStale failed', error, stack);
    }
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _listenerHandles) {
      _routineProvider.removeListener(listener);
      _catProvider.removeListener(listener);
    }
    _listenerHandles.clear();
    super.dispose();
  }
}

class _Planned {
  const _Planned({
    required this.key,
    required this.schedule,
    required this.notificationId,
  });
  final String key;
  final NotificationSchedule schedule;
  final int notificationId;
}
