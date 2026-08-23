import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/medication.dart';
import '../../../core/models/notification_schedule.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/notification_service.dart';
import '../../health/providers/medication_provider.dart';
import '../repositories/notification_schedule_repository.dart';
import 'notification_scheduler_service.dart' show NotificationSchedulerService;

/// Reactive bridge between [MedicationProvider] and the OS-level
/// notification surface.
///
/// Mirrors the routine scheduler:
///   * watches `MedicationProvider.medications` for the active cat
///   * upserts one [NotificationSchedule] per `medicationId × reminderTime`
///   * schedules the corresponding local notification
///   * cancels schedules for meds that became inactive or whose
///     `reminderTimes` shrank
class MedicationReminderScheduler extends ChangeNotifier {
  MedicationReminderScheduler({
    required NotificationScheduleRepository repository,
    required NotificationService notificationService,
    required MedicationProvider medicationProvider,
    required String Function() catIdProvider,
    DateTime Function()? clock,
  })  : _repository = repository,
        _notificationService = notificationService,
        _provider = medicationProvider,
        _catIdProvider = catIdProvider,
        _clock = clock ?? DateTime.now {
    _provider.addListener(_handleChanged);
    _listenerHandles.add(_handleChanged);
  }

  final NotificationScheduleRepository _repository;
  final NotificationService _notificationService;
  final MedicationProvider _provider;
  final String Function() _catIdProvider;
  final DateTime Function() _clock;

  final List<VoidCallback> _listenerHandles = <VoidCallback>[];
  bool _busy = false;
  bool get isBusy => _busy;

  Future<void> syncNow() => _sync();
  Future<void> cancelAll() async {
    await _notificationService.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _handleChanged() {
    _sync();
  }

  Future<void> _sync() async {
    if (_busy) return;
    final String? catId = _catIdProvider();
    if (catId == null) return;
    _busy = true;
    try {
      await _notificationService.initialize();
      final List<Medication> meds =
          _provider.records.where((Medication m) => m.active).toList();
      final List<_Planned> planned = <_Planned>[];
      for (final Medication med in meds) {
        planned.addAll(_planFromMedication(med, catId));
      }
      for (final _Planned p in planned) {
        await _repository.upsert(ownerId: catId, schedule: p.schedule);
        await _notificationService.schedule(
          id: p.notificationId,
          title: p.schedule.title,
          body: p.schedule.body,
          when: p.schedule.fireAt,
          payload: p.schedule.payload,
        );
      }
      // ignore: unawaited_futures
      _pruneStale(catId: catId, keep: planned);
    } catch (error, stack) {
      AppLogger.w('MedicationReminderScheduler.sync failed', error, stack);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Iterable<_Planned> _planFromMedication(Medication med, String catId) sync* {
    if (!med.active) return;
    final List<DateTime> slots = med.reminderTimes;
    if (slots.isEmpty) return;
    final DateTime now = _clock();
    for (final DateTime slot in slots) {
      final DateTime fire = _nextOccurrence(slot, now);
      final String key = 'medication:${med.id}:${_hm(slot)}';
      final NotificationSchedule schedule = NotificationSchedule(
        id: key,
        catId: catId,
        channelKey: AppConstants.notificationsChannelMedications,
        title: 'Medication reminder \u2014 ${med.name}',
        body: 'Time to give ${med.name} (${med.dose}).',
        fireAt: fire,
        payload: 'medication/${med.id}',
        sourceType: 'medication',
        sourceId: med.id,
      );
      yield _Planned(
        key: key,
        schedule: schedule,
        notificationId:
            NotificationSchedulerService.idForKey(key),
      );
    }
  }

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

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pruneStale({
    required String catId,
    required List<_Planned> keep,
  }) async {
    final Set<String> keepKeys = keep.map((p) => p.key).toSet();
    try {
      final stream = _repository.watchSchedules(ownerId: catId);
      final List<NotificationSchedule> existing = await stream.first;
      for (final NotificationSchedule s in existing) {
        if (s.sourceType != 'medication') continue;
        if (keepKeys.contains(s.id)) continue;
        await _repository.delete(ownerId: catId, scheduleId: s.id);
        await _notificationService
            .cancel(NotificationSchedulerService.idForKey(s.id));
      }
    } catch (error, stack) {
      AppLogger.w(
        'MedicationReminderScheduler.pruneStale failed',
        error,
        stack,
      );
    }
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _listenerHandles) {
      _provider.removeListener(listener);
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